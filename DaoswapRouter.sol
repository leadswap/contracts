pragma solidity >=0.5.16;

import './interfaces/IDaoswapDao.sol';
import './interfaces/IDaoswapPair.sol';
import './libraries/SafeMath.sol';
import './libraries/UniswapV2Library.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IWETH.sol';
import './interfaces/IERC20.sol';


contract DaoswapRouter {
    using SafeMath for uint;

    address public dao;
    address public WETH;

    function() external payable {
        require(WETH == msg.sender, 'Require WETH Only');
    }

    constructor(address _dao, address _WETH) public {
        dao = _dao;
        WETH = _WETH;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'DaoswapRouter: EXPIRED');
        _;
    }

    function _addLiquidity(
        address pair,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint amountA, uint amountB) {
        // return error if the pair doesn't exist yet
        require(pair != address(0), 'DaoswapRouter: PAIR_NOT_FOUND');
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(pair, tokenA);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'DaoswapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'DaoswapRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        address pair = IDaoswapDao(dao).getPair(tokenA, tokenB);
        (amountA, amountB) = _addLiquidity(pair, tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IDaoswapPair(pair).mint(msg.sender);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        address pair = IDaoswapDao(dao).getPair(token, WETH);
        (amountToken, amountETH) = _addLiquidity(
            pair,
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit.value(amountETH)();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IDaoswapPair(pair).mint(msg.sender);
        // // // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = IDaoswapDao(dao).getPair(tokenA, tokenB);
        IDaoswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IDaoswapPair(pair).burn(msg.sender, to);
        address _token0 = IDaoswapPair(pair).token0();
        (amountA, amountB) = tokenA == _token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'DaoswapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'DaoswapRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function _swap(address pair, uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address _token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == _token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? IDaoswapDao(dao).getPair(output, path[i + 2]) : _to;
            IDaoswapPair(pair).swap(amount0Out, amount1Out, to);
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        address pair = IDaoswapDao(dao).getPair(path[0], path[1]);
        amounts = UniswapV2Library.getAmountsOut(pair, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'DaoswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        _swap(pair, amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        address pair = IDaoswapDao(dao).getPair(path[0], path[1]);
        amounts = UniswapV2Library.getAmountsIn(pair, amountOut, path);
        require(amounts[0] <= amountInMax, 'DaoswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        _swap(pair, amounts, path, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'DaoswapRouter: INVALID_PATH');
        address pair = IDaoswapDao(dao).getPair(path[0], path[1]);
        amounts = UniswapV2Library.getAmountsOut(pair, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'DaoswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit.value(amounts[0])();
        assert(IWETH(WETH).transfer(pair, amounts[0]));
        _swap(pair, amounts, path, to);
    }
}