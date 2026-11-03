const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const logic = fs.readFileSync(path.join(__dirname, '../shared/logic/WeatherPanelLogic.js'), 'utf8').replace(/^.*\.pragma library\s*/m, '');

const source = fs.readFileSync(path.join(__dirname, '../shared/panels/WeatherPanel.qml'), 'utf8');
const start = source.indexOf('    function parseReport(raw) {');
const end = source.indexOf('\n    property real reveal:', start);
assert.ok(start >= 0 && end > start);

function fixture() {
    const panel = { temp: '20', feels: '21', desc: 'Previous', humidity: '50', wind: '3',
        location: 'Previous', latitude: 1, longitude: 2, forecastDays: [{ date: 'previous' }],
        locationDraft: 'Fixture' };
    const context = { wxPanel: panel, locationQuery: '1,2',
        openMeteoDescription: () => 'Clear sky', openMeteoWttrCode: () => 113 };
    vm.createContext(context);
    const helpers = vm.createContext({});
    vm.runInContext(logic, helpers);
    context.forecastCode = day => helpers.forecastCode(panel, {}, day);
    context.chanceOfRain = day => helpers.chanceOfRain(panel, {}, day);
    vm.runInContext(source.slice(start, end), context);
    return { panel, parse: value => context.parseReport(JSON.stringify(value)) };
}

function report() {
    return { current: { temperature_2m: 0, apparent_temperature: 0,
        relative_humidity_2m: 0, wind_speed_10m: 0, weather_code: 0 },
        daily: { time: ['2026-11-03'], temperature_2m_min: [0], temperature_2m_max: [0],
            weather_code: [0], precipitation_probability_max: [0] } };
}

test('incomplete or invalid Open-Meteo reports preserve all previous panel data', () => {
    const malformed = [null, { current: { temperature_2m: 99 } }];
    for (const field of Object.keys(report().current)) {
        for (const value of [null, 'invalid']) {
            const data = report(); data.current[field] = value; malformed.push(data);
        }
    }
    for (const field of Object.keys(report().daily)) {
        for (const value of [null, [], 'invalid']) {
            const data = report(); data.daily[field] = value;
            // An empty time array is a valid report with no forecast days.
            if (!(field === 'time' && Array.isArray(value) && value.length === 0)) malformed.push(data);
        }
    }
    for (const data of malformed) {
        const { panel, parse } = fixture();
        const before = JSON.stringify(panel);
        assert.equal(parse(data), false);
        assert.equal(JSON.stringify(panel), before);
    }
});

test('malformed wttr forecast preserves previous conditions and forecast', () => {
    for (const weather of [[null], [{ hourly: [null] }], [{ hourly: {} }], 'invalid', null]) {
        const { panel, parse } = fixture();
        const before = JSON.stringify(panel);
        assert.equal(parse({ current_condition: [{ temp_C: '99' }], weather }), false);
        assert.equal(JSON.stringify(panel), before);
    }
});

test('valid wttr conditions and hourly forecast update together', () => {
    const { panel, parse } = fixture();
    assert.equal(parse({ current_condition: [{ temp_C: '0', FeelsLikeC: '-2', humidity: '60',
        windspeedKmph: '5', weatherDesc: [{ value: 'Cloudy' }] }],
        weather: [{ date: '2026-11-03', mintempC: '-2', maxtempC: '3',
            hourly: [{ weatherCode: '119', chanceofrain: '20' }, { weatherCode: '113', chanceofrain: '40' }] }] }), true);
    assert.equal(panel.temp, '0');
    assert.equal(panel.desc, 'Cloudy');
    assert.equal(panel.forecastDays.length, 1);
    assert.equal(panel.forecastDays[0].code, '119');
    assert.equal(panel.forecastDays[0].rain, 40);
});

test('valid zero values update current conditions and forecast together', () => {
    const { panel, parse } = fixture();
    assert.equal(parse(report()), true);
    for (const field of ['temp', 'feels', 'humidity', 'wind']) assert.equal(panel[field], '0');
    assert.equal(panel.location, 'Fixture');
    assert.equal(panel.forecastDays.length, 1);
    assert.equal(panel.forecastDays[0].min, 0);
    assert.equal(panel.forecastDays[0].rain, 0);
});
