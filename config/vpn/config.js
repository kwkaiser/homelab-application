"use strict";
module.exports = {
  public: false,
  leaveMessage: "later gators",
  messageStorage: ["sqlite", "text"],
  storagePolicy: {
    enabled: false,
    maxAgeDays: 7,
    deletionPolicy: "everything",
  },
};