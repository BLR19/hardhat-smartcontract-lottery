const { assert, expect } = require("chai")
const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

developmentChains.includes(network.name) //If we are on a development chain (testnet)
    ? describe.skip
    : describe("Lottery Staging Tests", function () {
          let lottery, lotteryEntranceFee, deployer

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer //retrieve accounts manually from the attribute namedAccounts defined whithin hardhat.config.js
              lottery = await ethers.getContract("Lottery", deployer) //"Imports" the contract to be able to reach all the functions
              lotteryEntranceFee = await lottery.getEntranceFee()
          })

          describe("fulfillRandomWords", function () {
              it("works with live Chainlink Keepers and Chainlink VRF, we get a random winner", async function () {
                  const startingTimeStamp = await lottery.getLatestTimeStamp()
                  const accounts = await ethers.getSigners()

                  //Setup the listener before we enter the lottery
                  //In case the blockchain moves really fast

                  await new Promise(async (resolve, reject) => {
                      lottery.once("WinnerPicked", async () => {
                          console.log("WinnerPicked event fired!") //Once the listener has found the promise, let's do this stuff
                          try {
                              //If resolved, do this
                              const recentWinner = await lottery.getRecentWinner()
                              const lotteryState = await lottery.getLotteryState()
                              const winnerEndingBalance = await accounts[0].getBalance()
                              const endingTimeStamp = await lottery.getLatestTimeStamp()

                              await expect(lottery.getPlayer(0)).to.be.reverted //To check if the number of players has been reset
                              assert.equal(recentWinner.toString(), accounts[0].address) //To check if the winner has been set as last winner
                              assert.equal(lotteryState, 0)
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  winnerStartingBalance.add(lotteryEntranceFee).toString()
                              )
                              assert(endingTimeStamp > startingTimeStamp)
                              resolve()
                          } catch (e) {
                              reject(e)
                          }
                      })
                      const tx = await lottery.enterLottery({ value: lotteryEntranceFee })
                      await tx.wait(1)
                      console.log("Entering the lottery...")
                      const winnerStartingBalance = await accounts[0].getBalance() //Used to check if the amount of the lottery are gonna be added to it at the end
                  })
              })
          })
      })
