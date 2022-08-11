// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DEX {
    using SafeMath for uint256;
    IERC20 token;

    event EthToTokenSwap(address sender, uint256 eth, uint256 tokens);
    event TokenToEthSwap(address sender, uint256 tokens, uint256 eth);
    event LiquidityProvided(address sender, uint256 eth, uint256 tokens);
    event LiquidityRemoved(
        address sender,
        uint256 amount,
        uint256 ethAmount,
        uint256 tokenAmount
    );

    constructor(address token_addr) public {
        token = IERC20(token_addr);
    }

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    function init(uint256 tokenAmount) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX already has liquidity");
        totalLiquidity += address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(
            token.transferFrom(msg.sender, address(this), tokenAmount),
            "Transaction Failed!"
        );
        return totalLiquidity;
    }

    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public view returns (uint256 yOutput) {
        uint256 xFee = xInput.mul(997);
        uint256 numerator = (yReserves.mul(xFee));
        uint256 denominator = (xReserves.mul(1000)).add(xFee);
        return numerator / denominator;
    }

    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "No ETH sent!");
        uint256 ethInput = msg.value;
        uint256 amount = price(
            ethInput,
            address(this).balance.sub(ethInput),
            token.balanceOf(address(this))
        );
        require(
            token.transfer(msg.sender, amount),
            "Transaction failed to send!"
        );
        emit EthToTokenSwap(msg.sender, msg.value, amount);
        return amount;
    }

    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "No tokens sent!");
        uint256 amount = price(
            tokenInput,
            token.balanceOf(address(this)),
            address(this).balance
        );
        require(
            token.transferFrom(msg.sender, address(this), tokenInput),
            "Tokens failed to send!"
        );
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit TokenToEthSwap(msg.sender, tokenInput, amount);
        return amount;
    }

    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "ETH value sent must be greater than zero!");
        uint256 ethReserve = address(this).balance.sub(msg.value);
        uint256 tokenAmount = (token.balanceOf(address(this)).div(ethReserve))
            .mul(msg.value);
        require(
            token.transferFrom(msg.sender, address(this), tokenAmount),
            "Tokens failed to send"
        );
        uint256 liquidityMinted = (msg.value.mul(totalLiquidity)).div(
            ethReserve
        );
        totalLiquidity = totalLiquidity.add(liquidityMinted);
        liquidity[msg.sender] = liquidity[msg.sender].add(liquidityMinted);
        emit LiquidityProvided(msg.sender, msg.value, tokenAmount);
        return (tokenAmount);
    }

    function withdraw(uint256 amount)
        public
        returns (uint256 ethAmount, uint256 tokenAmount)
    {
        require(liquidity[msg.sender] > 0, "No liquidity provided!");
        uint256 providedLiquidity = liquidity[msg.sender];
        uint256 ethBalance = address(this).balance;
        uint256 tokenBalance = token.balanceOf(address(this));

        ethAmount = (amount.mul(ethBalance)).div(totalLiquidity);
        tokenAmount = (amount.mul(tokenBalance)).div(totalLiquidity);

        require(
            ethAmount > 0 && tokenBalance > 0,
            "Withdraw amount equals zero!"
        );

        liquidity[msg.sender] = liquidity[msg.sender].sub(amount);
        totalLiquidity = totalLiquidity.sub(amount);
        require(
            token.transfer(msg.sender, tokenAmount),
            "Failed to send tokens"
        );
        (bool sent, ) = msg.sender.call{value: ethAmount}("");
        require(sent, "Failed to send Ether");
        emit LiquidityRemoved(msg.sender, amount, ethAmount, tokenAmount);
        return (ethAmount, tokenAmount);
    }
}
