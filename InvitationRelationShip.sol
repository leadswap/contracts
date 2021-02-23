pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import './interfaces/IDelegate.sol';

interface IDAO {
    function getercBalanceof(address owner) external view returns (uint);
}


// contract DAO is IDAO {
//     function getercBalanceof(address owner) external view returns (uint){
//         return 1;
//     }
// }

contract InvitationRelationShip is IDelegate {
    
    event AddRelation(address, address);
    event DelRelation(address, address);
    event SetDaoConAddr(address);
    
    address constant ZERO_ADDRESS = address(0);
    
    modifier onlyOwner() {
        require(msg.sender == conOwnerAddr, "for contract owner only");
        _;
    }
    
    modifier needDaoConAddrSet() {
        require(daoAddress != ZERO_ADDRESS, "dao contract address not set");
        _;
    }
    
    modifier needAddrExist(address addr) {
        require(addrToDelegateAddr[addr] != ZERO_ADDRESS, "address is not existed");
        _;
    }
    
    modifier needAddrNotExist(address addr) {
        require(addrToDelegateAddr[addr] == ZERO_ADDRESS, "address has been existed already");
        _;
    }
    
    modifier needHasInvitationRelation(address addr, address inviter) {
        require(addrToDelegateAddr[addr] == inviter, "no invitation relation");
        _;
    }
    
    constructor() public {
        conOwnerAddr = msg.sender;
        
        // TODO init Invitation root address
        deleRootAddr = address(0xFF);
        
        // TODO reward ranks
        rewardRanks = 3;
        
        // TODO reward ranks detail (percent)
        rewardRanksDetail = [10, 5, 2];
        
        // TODO max members per delegate
        maxMemberCount = 100;
        
        // TODO min token value needs
        minTokenNeeds = 0;
        
        // TODO max delegate ranks to trace
        maxDelegateRanks = 3;
    }
    
    function set_dao_contract_address(address daoConAddr) external
    onlyOwner()
    {
        daoAddress = daoConAddr;
        emit SetDaoConAddr(daoConAddr);
    }
    
    function add_invitation_relation(address inviterCode) 
    needDaoConAddrSet()
    needAddrNotExist(msg.sender)
    external {
        if ((inviterCode == deleRootAddr) || (inviterCode == ZERO_ADDRESS)) {
            addrToDelegateAddr[msg.sender] = deleRootAddr;
            addrToMemberAddrs[deleRootAddr].push(msg.sender);
            emit AddRelation(msg.sender, inviterCode);
            return;
        } else {
            require(addrToDelegateAddr[inviterCode] != ZERO_ADDRESS, "address is not existed");
        }
        
        bool found = false;
        address[] memory memberAddrs;
        address inviter = inviterCode;
        for (uint32 i = 0; i < maxDelegateRanks + 1; i++) {
            memberAddrs = addrToMemberAddrs[inviter];
            uint256 balance = IDAO(daoAddress).getercBalanceof(inviter);
            if ((memberAddrs.length >= maxMemberCount) || (balance < minTokenNeeds)) {
                // do nothing and go ahead
            } else {
                // find, break
                found = true;
                break;
            }
            
            address delegateAddr = addrToDelegateAddr[inviter];
            if (delegateAddr == ZERO_ADDRESS) {
                // no delegate, break
                break;
            } else {
                inviter = delegateAddr;
            }
        }
        
        // not found at final
        if (!found) {
            inviter = deleRootAddr;
        }
        
        addrToDelegateAddr[msg.sender] = inviter;
        addrToMemberAddrs[inviter].push(msg.sender);
        
        emit AddRelation(msg.sender, inviter);
    }
    
    function del_invitation_relation(address addr)
    needDaoConAddrSet()
    needAddrExist(msg.sender) 
    needAddrExist(addr) 
    needHasInvitationRelation(addr, msg.sender)
    external {
        //remove orig invitation relation
        bool found = false;
        uint32 index = 0;
        address inviter = msg.sender;
        
        delete addrToDelegateAddr[addr];
        address[] storage origMemberAddrs = addrToMemberAddrs[inviter];
        for (index = 0; index < origMemberAddrs.length; index++) {
            if (origMemberAddrs[index] == addr) {
                found = true;
                break;
            }
        }
        
        if (found) {
            if (index != origMemberAddrs.length - 1) {
                delete origMemberAddrs[index];
                origMemberAddrs[index] = origMemberAddrs[origMemberAddrs.length-1];
            }
            origMemberAddrs.length--;
            emit DelRelation(addr, inviter);
        }
        
        // add new invitation relation
        found = false;
        address[] memory memberAddrs;
        inviter = addrToDelegateAddr[inviter];
        if (inviter != ZERO_ADDRESS) {
            for (uint32 i = 0; i < maxDelegateRanks; i++) {
                memberAddrs = addrToMemberAddrs[inviter];
                uint256 balance = IDAO(daoAddress).getercBalanceof(inviter);
                if ((memberAddrs.length >= maxMemberCount) || (balance < minTokenNeeds)) {
                    // do nothing and go ahead
                } else {
                    // find, break
                    found = true;
                    break;
                }
            
                address delegateAddr = addrToDelegateAddr[inviter];
                if (delegateAddr == ZERO_ADDRESS) {
                    // no delegate, break
                    break;
                } else {
                    inviter = delegateAddr;
                }
            }
           
        } 
        
        // not found at final
        if (!found) {
            inviter = deleRootAddr;
        }
        
        addrToDelegateAddr[addr] = inviter;
        addrToMemberAddrs[inviter].push(addr);
        
        emit AddRelation(addr, inviter);
    }
    
    function getDelegateRewardRanks(address addr) external view returns (DelegatePre[] memory)
    {
        uint32 index = 0;
        DelegatePre[] memory delegatePreRet = new DelegatePre[] (rewardRanks);
        address memberAddr = addr;
    	for(;;) {
    	    address delegateAddr = addrToDelegateAddr[memberAddr];
    	    if (delegateAddr == ZERO_ADDRESS) {
    	        break;
    	    }
    	    
    	    delegatePreRet[index].delegateAddr = delegateAddr;
    	    delegatePreRet[index].delegateReward = rewardRanksDetail[index];
    	    
    	    if (index >= rewardRanks - 1) {
    	        break;
    	    }
    	    
    	    memberAddr = delegateAddr;
    	    index++;
    	}
    	
    	return delegatePreRet;
    }
    
    function getCaller() external view returns (address) {
        return msg.sender;
    }
    
    function getDaoContractAddr() external view returns (address) {
        return daoAddress;
    }
    
    function getConOwnerAddr() external view returns (address) {
        return conOwnerAddr;
    }
    
    function getDelegateRoot() external view returns (address) {
        return deleRootAddr;
    }
    
    function getDelegate(address addr) external view returns (address) 
    {
        address delegateAddr = addrToDelegateAddr[addr];
        return delegateAddr;
    }
    
    function getMembersCount(address deleAddr) external view returns (uint32)
    {
        address[] memory memberAddrs = addrToMemberAddrs[deleAddr];
        return uint32(memberAddrs.length);
    }
    
    function getMembers(address deleAddr) external view returns (address[] memory)
    {
        address[] memory memberAddrs = addrToMemberAddrs[deleAddr];
        return memberAddrs;
    }
    
    // struct DelegatePre{
    //     address delegateAddr;
    //     uint32  delegateReward;
    // }
    
    // contract owner address
    address internal conOwnerAddr;
    
    // DAO contract address
    address internal daoAddress;
    
    // delegate root address
    address internal deleRootAddr;
    
    // token reward ranks
    uint32 internal rewardRanks;
    
    // token reward details
    uint32[] internal rewardRanksDetail;
    
    // max members count per delegate
    uint32 internal maxMemberCount;
    
    // min token value needs
    uint256 internal minTokenNeeds;
    
    // max delegate ranks to trace
    uint32 internal maxDelegateRanks;
    
    // k-v from member address to delegate address
    mapping(address => address) internal addrToDelegateAddr;
    
    // k-v from delegate address to member addresses
    mapping(address => address[]) internal addrToMemberAddrs;
}
