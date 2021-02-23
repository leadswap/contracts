pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;
interface IDelegate {
    struct DelegatePre{
        address delegateAddr;
        uint32  delegateReward;
    }
    function getDelegateRewardRanks(address addr) external view returns (DelegatePre[] memory);
}