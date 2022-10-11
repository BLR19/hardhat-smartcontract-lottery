const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.utils.parseEther("0.25") //0.25 LINK is the premium, the cost at each random number ask
const GAS_PRICE_LINK = 1e9 //LINK per gas, fluctuate with the price of the gqs from the blockchain

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const args = [BASE_FEE, GAS_PRICE_LINK]
    /*const chainId = network.config.chainId*/
    if (developmentChains.includes(network.name)) {
        //or if(chainId == "31337")
        log("Local network detected! Deploying mocks...")
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks deployed!")
        log("-------------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
