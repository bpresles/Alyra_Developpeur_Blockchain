const HDWalletProvider = require("@truffle/hdwallet-provider");

const mnemonicPhrase = "lawsuit sting mobile rack problem sick uncover short luggage notice seed sudden"; // 12 word mnemonic

module.exports = {
  networks: {
    development: {
     host: "127.0.0.1",
     port: 8545,
     network_id: "*"
    },
    dashboard: {
    }
  },
  compilers: {
    solc: {
      version: "0.8.17",
    }
  },
  db: {
    enabled: false,
    host: "127.0.0.1",
  }
};
