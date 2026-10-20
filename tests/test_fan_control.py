"""Isolated hwmon fixtures: no hardware writes."""
import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('fan', 'scripts/rise-fan-control')
spec = importlib.util.spec_from_loader(loader.name, loader)
fan = importlib.util.module_from_spec(spec)
loader.exec_module(fan)


class FanControlTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.device = self.root / 'hwmon5'
        self.device.mkdir()
        for name, value in {'name': 'nct6791', 'pwm2': '180', 'pwm2_enable': '5', 'pwm2_temp_sel': '7', 'temp7_label': 'PECI Agent 0'}.items():
            (self.device / name).write_text(value)
        cpu = self.root / 'hwmon6'
        cpu.mkdir()
        (cpu / 'name').write_text('coretemp')
        self.sensor = cpu / 'temp1_input'
        self.sensor.write_text('45000')
        self.real_temperature = fan.temperature
        self.real_channels = fan.channels
        self.patches = [patch.object(fan, 'channels', lambda: self.real_channels(self.root)),
                        patch.object(fan, 'temperature', lambda: self.real_temperature(self.root))]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)
        self.controller = fan.Controller()
        self.addCleanup(self.controller.restore)

    def request(self, mode='silent', percent=60):
        return {'id': str(self.device / 'pwm2'), 'mode': mode, 'percent': percent}

    def test_discovery_excludes_gpu_and_never_assumes_cpu_header(self):
        gpu = self.root / 'hwmon7'
        gpu.mkdir()
        for name, value in {'name': 'amdgpu', 'pwm1': '100', 'pwm1_enable': '2'}.items():
            (gpu / name).write_text(value)
        channels = fan.channels()
        self.assertEqual(len(channels), 1)
        self.assertEqual(channels[0]['label'], 'nct6791 / pwm2')

    def test_apply_thermal_override_and_exact_restore(self):
        self.controller.apply(self.request('manual', 40))
        self.assertEqual((self.device / 'pwm2_enable').read_text(), '1')
        self.assertEqual((self.device / 'pwm2').read_text(), '102')
        self.sensor.write_text('85000')
        self.controller.tick()
        self.assertEqual((self.device / 'pwm2').read_text(), '255')
        self.controller.restore()
        self.assertEqual((self.device / 'pwm2').read_text(), '180')
        self.assertEqual((self.device / 'pwm2_enable').read_text(), '5')

    def add_second_cpu_fan(self):
        for name, value in {'pwm1': '200', 'pwm1_enable': '5',
                            'pwm1_temp_sel': '7', 'fan1_input': '0',
                            'pwm3': '190', 'pwm3_enable': '5',
                            'pwm3_temp_sel': '1', 'temp1_label': 'SYSTIN'}.items():
            (self.device / name).write_text(value)

    def test_auto_selects_both_cpu_channels_including_zero_rpm(self):
        self.add_second_cpu_fan()
        selected = fan.automatic_channels(fan.channels())
        self.assertEqual([Path(c['id']).name for c in selected], ['pwm1', 'pwm2'])
        # sysfs temperature numbering can change across boots.
        (self.device / 'pwm2_temp_sel').write_text('9')
        (self.device / 'temp9_label').write_text('PECI Agent 0')
        self.assertEqual(len(fan.automatic_channels(fan.channels())), 2)

    def test_group_applies_and_restores_both_cpu_channels(self):
        self.add_second_cpu_fan()
        group = fan.AutomaticController()
        self.addCleanup(group.restore)
        group.apply({'mode': 'manual', 'percent': 60})
        for channel in ['pwm1', 'pwm2']:
            self.assertEqual((self.device / channel).read_text(), '153')
            self.assertEqual((self.device / (channel + '_enable')).read_text(), '1')
        self.assertEqual((self.device / 'pwm3').read_text(), '190')
        self.sensor.write_text('85000')
        group.tick()
        for channel in ['pwm1', 'pwm2']:
            self.assertEqual((self.device / channel).read_text(), '255')
        group.restore()
        self.assertEqual((self.device / 'pwm1').read_text(), '200')
        self.assertEqual((self.device / 'pwm2').read_text(), '180')
        for channel in ['pwm1', 'pwm2']:
            self.assertEqual((self.device / (channel + '_enable')).read_text(), '5')

    def test_group_rolls_back_if_second_channel_fails(self):
        self.add_second_cpu_fan()
        group = fan.AutomaticController()
        available = fan.channels()
        for channel in available:
            if Path(channel['id']).name == 'pwm2':
                channel['writable'] = False
        with patch.object(fan, 'channels', return_value=available):
            with self.assertRaises(ValueError):
                group.apply({'mode': 'full'})
        self.assertEqual((self.device / 'pwm1').read_text(), '200')
        self.assertEqual((self.device / 'pwm1_enable').read_text(), '5')

    def test_nct_rejects_pwm_writes_until_manual_mode(self):
        original_write = Path.write_text
        def hwmon_write(path, value, *args, **kwargs):
            if path.parent == self.device and path.name in {'pwm1', 'pwm2'}:
                enable = path.with_name(path.name + '_enable')
                if enable.read_text() != '1':
                    raise OSError(16, 'Device or resource busy')
            return original_write(path, value, *args, **kwargs)
        self.add_second_cpu_fan()
        group = fan.AutomaticController()
        with patch.object(Path, 'write_text', hwmon_write):
            try:
                group.apply({'mode': 'full'})
                for channel in ['pwm1', 'pwm2']:
                    self.assertEqual((self.device / channel).read_text(), '255')
            finally:
                group.restore()
        self.assertEqual((self.device / 'pwm1').read_text(), '200')
        self.assertEqual((self.device / 'pwm2').read_text(), '180')
        for channel in ['pwm1', 'pwm2']:
            self.assertEqual((self.device / (channel + '_enable')).read_text(), '5')

    def test_profiles_are_monotonic_and_ordered(self):
        for mode in ['silent', 'standard', 'performance', 'full']:
            values = [fan.duty(mode, 60, t) for t in range(20, 100)]
            self.assertEqual(values, sorted(values))
            self.assertEqual(values[-1], 100)
        self.assertLess(fan.duty('silent', 60, 45), fan.duty('standard', 60, 45))
        self.assertLess(fan.duty('standard', 60, 45), fan.duty('performance', 60, 45))

    def test_missing_temperature_and_invalid_requests_do_not_write(self):
        for request in [self.request('bad'), self.request('manual', 0),
                        {'id': '/tmp/arbitrary', 'mode': 'full'}]:
            with self.assertRaises(ValueError):
                self.controller.apply(request)
        self.sensor.unlink()
        with self.assertRaises(ValueError):
            self.controller.apply(self.request())
        self.assertEqual((self.device / 'pwm2_enable').read_text(), '5')

    def test_eof_restores_active_controller(self):
        import io
        self.add_second_cpu_fan()
        group = fan.AutomaticController()
        self.addCleanup(group.restore)
        group.apply({'mode': 'silent'})
        with patch.object(fan, 'AutomaticController', return_value=group), \
             patch.object(fan.sys, 'stdin', io.StringIO('')), \
             patch.object(fan, 'emit'), \
             patch.object(fan.select, 'select', return_value=([True], [], [])):
            fan.main()
        self.assertEqual((self.device / 'pwm2_enable').read_text(), '5')
        self.assertEqual((self.device / 'pwm2').read_text(), '180')
        self.assertEqual((self.device / 'pwm1').read_text(), '200')
        self.assertEqual((self.device / 'pwm1_enable').read_text(), '5')

    def test_sensor_loss_forces_full_before_reporting_failure(self):
        self.controller.apply(self.request())
        self.sensor.unlink()
        with self.assertRaises(ValueError):
            self.controller.tick()
        self.assertEqual((self.device / 'pwm2').read_text(), '255')


if __name__ == '__main__':
    unittest.main()
