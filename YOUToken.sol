pragma solidity=0.5.16;

import './libraries/SafeMath.sol';
import './interfaces/IERCMint20.sol';

contract YOUToken is IERCMint20 {
    using SafeMath for uint;

    string public constant name = 'LEAD';
    string public constant symbol = 'LEAD';
    uint8 public constant decimals = 18;
    //uint public constant max_mint_number = 200000 * (10 ** uint(decimals));
    uint public constant max_mint_number_first_phase = 21000000*(10**uint(decimals));
    uint public constant max_mint_number_second_phase = (52500000 - 21000000)*(10**uint(decimals));
    address public second_phase_pair_addr = address(0);
    uint public second_phase_start_block_number = 0;
    uint  public totalSupply_first_phase;
    uint  public totalSupply_second_phase;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    mapping(address => mapping(address=>uint)) public user_swap_payblock;
    address public owner;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() public {
        owner = msg.sender;
    }
    function changeOwner(address new_owner) external{
        require(msg.sender == owner);
        owner = new_owner;
    }
    function _mint(address to,address swap_addr, uint value) internal {
        if(swap_addr == second_phase_pair_addr){
            totalSupply_second_phase = totalSupply_second_phase.add(value);
        }else{
            totalSupply_first_phase = totalSupply_first_phase.add(value);
        }
        balanceOf[to] = balanceOf[to].add(value); // is initial value 0?
        emit Transfer(address(0), to, value);
    }

    function _approve(address origen_owner, address spender, uint value) private {
        allowance[origen_owner][spender] = value;
        emit Approval(origen_owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }
    function mint(address to, uint value,address swap_addr) external{
        require(msg.sender == owner);
        uint totalSupply = 0;
        uint max_mint_number = 0;
        if(swap_addr == second_phase_pair_addr){
            require(second_phase_start_block_number != 0,"second phase not start");
            totalSupply = totalSupply_second_phase;
            max_mint_number = max_mint_number_second_phase;
        }else{
            totalSupply = totalSupply_first_phase;
            max_mint_number = max_mint_number_first_phase;
        }
        uint realMint = value;
        if(totalSupply.add(value) > max_mint_number){
            realMint = max_mint_number.sub(totalSupply);
        }
        if(realMint == 0){
            return;
        }
        _mint(to,swap_addr,realMint);
    }
    function setSecondPhaseStart(uint256 blocknumber,address swap_addr)external{
        require(msg.sender == owner);
        second_phase_start_block_number = blocknumber;
        second_phase_pair_addr = swap_addr;
    }
    function getStartblock(address user,address swap_addr) external view returns (uint256 lastblocknum){
        return user_swap_payblock[user][swap_addr];
    }
	function setAddressBlock(address user,address swap_addr,uint256 lastblocknum) external returns (bool success){
	    require(msg.sender == owner);
	    user_swap_payblock[user][swap_addr] = lastblocknum;
	    return true;
	}
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }
    function getSwapTotalSupplyLeft(address swap_addr) external view returns (uint){
        if(swap_addr == second_phase_pair_addr){
            return max_mint_number_second_phase.sub(totalSupply_second_phase);
        }else{
            return max_mint_number_first_phase.sub(totalSupply_first_phase);
        }

    }
}
