module.exports =
  connections:
    mongo:
      adapter: 'sails-mongo'
      driver: 'mongodb'
      url: process.env.DB || 'mongodb://@im_mongo:27017/im'
