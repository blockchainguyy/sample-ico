require("babel-register");
require("babel-polyfill");

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 3600000,
      gasPrice: 21
    },
    ganache: {
      host: "localhost",
      port: 7545,
      network_id: 5777,
      gas: 6721975,
      gasPrice: 21
    }
  }
};
