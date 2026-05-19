const mongoose = require('mongoose');
require('dotenv').config({ path: 'e:/rice_mill_/server/.env' });
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/ricemill';

const UserSettings = mongoose.model('UserSettings', new mongoose.Schema({
  userEmail: String,
  cmdLimit: Number,
  cmdMaxGauge: Number,
  powerLimit: Number,
  powerMaxGauge: Number,
  pfLimit: Number
}), 'usersettings');

async function check() {
  await mongoose.connect(MONGO_URI);
  const settings = await UserSettings.find();
  console.log('All User Settings:', JSON.stringify(settings, null, 2));
  process.exit(0);
}

check();
