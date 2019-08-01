const { notarize } = require('electron-notarize')
const flags = require('flags');

flags.defineString('appBundleId');
flags.defineString('appPath');

flags.parse();

if (!flags.get('appBundleId')) {
  console.error('please pass --appBundleId net.adoptopenjdk.11.jdk')
  process.exit(1)
}

if (!flags.get('appPath')) {
  console.error('please pass --appPath /path/to/installer.pkg')
  process.exit(1)
}

let appBundleId = flags.get('appBundleId')
let appPath = flags.get('appPath')
let appleId = process.env.appleId
let appleIdPassword = process.env.appleIdPassword

async function packageTask () {
  // Package your app here, and code side with hardened runtime
  await notarize({
    appBundleId,
    appPath,
    appleId,
    appleIdPassword,
  });
}

packageTask()
