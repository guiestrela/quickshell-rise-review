const [action] = process.argv.slice(2);
if (action === "status") {
  process.stdout.write("Status: Connected\nCountry: Testland\n");
  process.exit(0);
}
process.stderr.write(`QR04N stub refused non-read command: ${action || "<none>"}\n`);
process.exit(86);
