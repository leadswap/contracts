pragma solidity >=0.5.0;

interface IDaoswapDao {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    //function createPair(address tokenA, address tokenB) external returns (address pair);
    function createPair(address pair) external;
    function changeSwapShare(address user,uint256 origin_amount,uint256 amount,bool add)external;
    function getercBalanceof(address owner)external view returns (uint);
}
