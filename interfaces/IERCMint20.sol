pragma solidity >=0.5.0;
interface IERCMint20 {
    function mint(address to,uint256 amount,address swap_addr) external;
	function setSecondPhaseStart(uint256 blocknumber,address pair_address)external;
	function getStartblock(address user,address swap_addr) external view returns (uint256 lastblocknum);
	function setAddressBlock(address user,address swap_addr,uint256 lastrewardblocknum) external returns (bool success);
	function balanceOf(address owner) external view returns (uint);
	function getSwapTotalSupplyLeft(address swap_addr) external view returns (uint);
}