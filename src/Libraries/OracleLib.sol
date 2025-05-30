// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();

    uint256 public constant TIMEOUT = 3 hours;
  function staleCheckLatestRoundData (AggregatorV3Interface priceFeed) public view returns(uint80, int256 ,uint256,uint256,uint80){
   (uint80 roundID, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

   uint256 timeDiff = block.timestamp - updatedAt;
   if(timeDiff > TIMEOUT){
    revert OracleLib__StalePrice();
   }
   return (roundID, price, startedAt, updatedAt, answeredInRound);
   
  }
}

