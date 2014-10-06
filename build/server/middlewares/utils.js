// Generated by CoffeeScript 1.8.0
var checkPermissions, db, deleteFiles, helpers, locker;

locker = require('../lib/locker');

db = require('../helpers/db_connect_helper').db_connect();

helpers = require('../helpers/utils');

checkPermissions = helpers.checkPermissions;

deleteFiles = helpers.deleteFiles;

module.exports.lockRequest = function(req, res, next) {
  req.lock = req.params.id || req.params.type;
  return locker.runIfUnlock(req.lock, function() {
    locker.addLock(req.lock);
    return next();
  });
};

module.exports.unlockRequest = function(req, res) {
  return locker.removeLock(req.lock);
};

module.exports.getDoc = function(req, res, next) {
  return db.get(req.params.id, function(err, doc) {
    if ((err != null) && err.error === "not_found") {
      deleteFiles(req.files);
      err = new Error('not found');
      err.status = 404;
      return next(err);
    } else if (err != null) {
      console.log("[Get doc] err: " + JSON.stringify(err));
      deleteFiles(req.files);
      return next(new Error(err.error));
    } else if (doc != null) {
      req.doc = doc;
      return next();
    } else {
      deleteFiles(req.files);
      err = new Error('not found');
      err.status = 404;
      return next(err);
    }
  });
};

module.exports.checkPermissionsFactory = function(permission) {
  return function(req, res, next) {
    return checkPermissions(permission, req.header('authorization'), next);
  };
};

module.exports.checkPermissionsByDoc = function(req, res, next) {
  return checkPermissions(req.doc.docType, req.header('authorization'), next);
};

module.exports.checkPermissionsByBody = function(req, res, next) {
  return checkPermissions(req.body.docType, req.header('authorization'), next);
};

module.exports.checkPermissionsByType = function(req, res, next) {
  return checkPermissions(req.params.type, req.header('authorization'), next);
};
