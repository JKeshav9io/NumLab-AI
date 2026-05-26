'use strict';

const env = require('./config/env');
const logger = require('./config/logger');
const createApp = require('./app');

const app = createApp();

app.listen(env.PORT, () => {
  logger.info(`NumLab API running on port ${env.PORT} [${env.NODE_ENV}]`);
});
