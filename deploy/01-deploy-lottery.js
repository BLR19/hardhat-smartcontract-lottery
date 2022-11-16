const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const VRF_SUB_FUND_AMOUNT = ethers.utils.parseEther("2")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    let VRFCoordinatorV2Address, subscriptionId
    const chainId = network.config.chainId

    if (developmentChains.includes(network.name)) {
        //if this is a local network
        const VRFCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        VRFCoordinatorV2Address = VRFCoordinatorV2Mock.address //use the VRFCoordinator address from the mock
        const transactionResponse = await VRFCoordinatorV2Mock.createSubscription() //automate the subscription and the funding
        const transactionReceipt = await transactionResponse.wait(1)
        subscriptionId = transactionReceipt.events[0].args.subId
        await VRFCoordinatorV2Mock.fundSubscription(subscriptionId, VRF_SUB_FUND_AMOUNT) //We don't need the LINK token on a local network
    } else {
        //SUBSCRIPTION COULD BE DONE THE SAME WAY AS WHEN WE ARE ON A LOCAL NETWORK
        //Please use the website
        VRFCoordinatorV2Address = networkConfig[chainId]["VRFCoordinatorV2"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
    }

    const entranceFee = networkConfig[chainId]["entranceFee"]
    const gasLane = networkConfig[chainId]["gasLane"]
    const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"]
    const interval = networkConfig[chainId]["interval"]

    const args = [
        VRFCoordinatorV2Address,
        entranceFee,
        gasLane,
        subscriptionId,
        callbackGasLimit,
        interval,
    ]

    const lottery = await deploy("Lottery", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 6,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(lottery.address, args)
    }
    log("___________________________________")
}

module.exports.tags = ["all", "lottery"]
