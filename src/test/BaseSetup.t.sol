pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Utilities} from "./utils/Utilities.sol";

import {Exchange} from "../Exchange.sol";
import {MyToken} from "../MyToken.sol";

contract BaseSetup is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;

    address internal user2;
    address internal user1;
    // setup the deployer so we dont have to constantly switch to a user
    address internal deployer;

    Exchange public dex;
    MyToken public token;

    constructor() {
        utils = new Utilities();
        users = utils.createUsers(5);
        user1 = users[0];
        vm.label(user1, "Alice");
        user2 = users[1];
        vm.label(user2, "Bob");
        deployer = address(this);

        token = new MyToken(15000);
        dex = new Exchange(address(token));

        token.transfer(user1, 5000 ether);
        token.transfer(user2, 5000 ether);
        token.transfer(deployer, 5000 ether);
        vm.deal(user1, 5000 ether);
        vm.deal(user2, 5000 ether);
        vm.deal(deployer, 5000 ether);

        token.approve(address(dex), 5000 ether);
        vm.prank(user1);
        token.approve(address(dex), 5000 ether);
        vm.prank(user2);
        token.approve(address(dex), 5000 ether);
    }
}
