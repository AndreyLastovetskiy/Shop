// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

contract ShopManager {

    //Структура ролей в системе
    enum Role {
        OWNER,
        SELLER,
        BUYER
    }
    Role currentRole;

    uint256 productsPrice = 100000000000000;

    //Структура магазина в системе
    struct Shop {
        string name;
        address owner;
        uint32[] products;
        bool exists;
    }

    //Структура пользователей в системе
    struct User {
        string username;
        string shop;
        bytes32 passwordHash;
        bytes32 secretHash;
        Role maxRole;
        Role currentRole;
        bool exists;
    }

    //Структура заявки на повышение роли
    struct ElevateRequest {
        address sender;
        Role role;
        string shop;
        bool exists;
    }

    //Структура товара
    struct Product {
        uint256 id;
        address shop;
        string title;
        string description;
        uint256 amount;
        uint256 price;
    }

    struct BuyRequest {
        address author;
        address shop;
        uint256 productId;
        uint256 amount;
        bool accepted;
        bool reviewed;
        bool exists;
    }
    mapping(uint256 => BuyRequest) BuyRequests;
    mapping(address => BuyRequest) AddressRequest;
    address[] AddressRequests;

    // Маппинг и массив для работы со всеми структурами ПОЛЬЗОВАТЕЛЕЙ
    mapping(address => User) users;
    mapping(string => address) userLogins;
    string[] userLoginsArray;

    // Запросы на смену роли по пользователям
    mapping(address => ElevateRequest) elevReqs;
    address[] elevReqsArray;

    //Товары по магазинам
    mapping(uint256 => Product) products;
    mapping(string => Product) productsDecrip;
    uint256[] productIds;

    // Магазины
    mapping(string => Shop) shops;
    string[] shopCities;

    //Модификатор для работы функции, которую может запустить только владелец системы OWNER
    modifier onlyOwner() {
        require(users[msg.sender].currentRole == Role.OWNER, "Only can do it Owner!");
        _;
    }

    //Модификатор для работы функции, которую может запустить только продавец SELLER
    modifier onlySeller() {
        require(users[msg.sender].currentRole == Role.SELLER, "Only can do it Seller!");
        _;
    }

    modifier onlyShopSeller(string memory shopCity) {
        require(keccak256(abi.encodePacked(users[msg.sender].shop)) == keccak256(abi.encodePacked(shopCity)), "You have to be a seller in required shop");
        _;
    }

    //Модификатор для работы функции, которую может запустить только продавец BUYER
    modifier onlyBuyer() {
        require(users[msg.sender].currentRole == Role.BUYER, "Only can do it Buyer!");
        _;
    }

    //Модификатор для работы функции, котоую может вызвать только покупатель и продавец BUYER и SELLER
    modifier onlySellerAndBuyer() {
        require(users[msg.sender].currentRole == Role.SELLER && users[msg.sender].currentRole == Role.BUYER, "Only can do it Seller and Buyer!");
        _;
    }

    //Функция создания нового пользователя (по умолчанию покупатель)
    function createUser(
        address addr,
        string memory username,
        string memory passwordHash,
        string memory secretHash
    ) public {
        require(!users[addr].exists && !users[userLogins[username]].exists, "User already exist");

        userLoginsArray.push(username);
        userLogins[username] = addr;
        users[addr] = User(
            username,
            "",
            keccak256(abi.encodePacked(passwordHash)),
            keccak256(abi.encodePacked(secretHash)),
            Role.BUYER,
            Role.BUYER,
            true
        );
    }

    //Функцкия авторизации пользователя в системе 
    function authorizateUser(
        string memory username,
        string memory password,
        string memory secret
    ) public view returns (bool success) {
        User memory user = users[userLogins[username]];

        require(user.exists, "User does not exist");
        require(
            //encodePacked(password)) == user.passwordHash
            keccak256(abi.encodePacked(password)) == user.passwordHash && keccak256(abi.encodePacked(secret)) == user.secretHash,
            "Wrong password or secret"
        );

        return true;
    }

    //Функция подтверждения заявки на повышение роли 
    function approveElevateRequest(address requestAuthor, bool accept) public onlyOwner {
        elevReqs[requestAuthor].exists = false;
        if(!accept) return;
    }

    //Функция отмены запроса на смену роли
    function cancelElevationRequest() public onlyOwner {
        require(
            elevReqs[msg.sender].exists,
            "You have not sent any elevate requests!"
        );

        elevReqs[msg.sender].exists = false;
        for (uint256 i = 0; i < elevReqsArray.length; i++) {
            if (elevReqsArray[i] == msg.sender) {
                delete elevReqsArray[i];
            }
        }
    }

    //Функция ввода нового администратора(только для администратора)
    function createNewOwner(
        address addr,
        string memory username,
        string memory passwordHash,
        string memory secretHash
    ) public onlyOwner {
        require(!users[addr].exists && !users[userLogins[username]].exists, "User already exist");

        userLoginsArray.push(username);
        userLogins[username] = addr;
        users[addr] = User(
            username,
            "",
            keccak256(abi.encodePacked(passwordHash)),
            keccak256(abi.encodePacked(secretHash)),
            Role.OWNER,
            Role.OWNER,
            true
        );
    }

    //Функция запроса на смену роли
    function newElevateRequest(Role requiredRole, string memory requiredShop) public onlySellerAndBuyer returns(bool) {
        require(!elevReqs[msg.sender].exists, "You have already sent an elevate request!");

        elevReqs[msg.sender] = ElevateRequest(
            msg.sender,
            requiredRole,
            requiredShop,
            true
        );
        elevReqsArray.push(msg.sender);

        return true;
    }

    //Функция добавления товара для магазина
    function createProductForShop(
        address addr,
        string memory title,
        string memory description,
        uint256 amount,
        uint256 price
    ) public onlySeller returns(bool) {
        products[productIds.length] = Product (
            productIds.length,
            addr,
            title,
            description,
            amount,
            price
        );
        productIds.push(productIds.length);

        return true;
    }

    //Функция создания заявки на покупку товара в магазине
    function buyProduct(address shop, address sender, uint256 productId, uint256 amount) public payable returns(bool) {
        BuyRequests[productIds.length] = BuyRequest(
            sender,
            shop,
            productId,
            amount,
            false,
            false,
            true 
        );
        AddressRequests.push(sender);

        uint256 amountToPay = amount * productsPrice;
        require(msg.value == amountToPay, "You need to send exact amount of ether that is required to buy product");

        return true;
    }

    //Функция, которая возвращает информацию о товаре 
    function allInfoProduct(string memory productTitle) public view returns(string memory title, string memory description, uint256 amount, uint256 price) {
        return (productsDecrip[productTitle].title, productsDecrip[productTitle].description, productsDecrip[productTitle].amount, productsDecrip[productTitle].price);
    }

    //Функция, которая подтверждает покупку товара(подтвержает SELLER)
    function acceptedBuyProduct(address sender) public onlySeller returns(bool) {
        AddressRequest[sender].accepted = true;
        AddressRequest[sender].reviewed = true;

        return true;
    }

    //Функция, которая отменяет покупку товара(подтвержает SELLER)
    function cancelBuyProduct(uint256 productId) public onlySeller returns(bool) {
        BuyRequests[productId].reviewed = true;

        return true;
    }

    //Функция, которая отменяет покупку товара(отменяет BUYER)
    function cancelRequestBuyProduct(uint256 productId) public onlyBuyer returns(bool) {
        BuyRequests[productId].exists = false;

        return true;
    }

        constructor() {

        users[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = User (
            "Owner",
            "",
            0x1841d653f9c4edda9d66a7e7737b39763d6bd40f569a3ec6859d3305b72310e6,
            0x64e604787cbf194841e7b68d7cd28786f6c9a0a3ab9f8b0a0e87cb4387ab0107,
            Role.OWNER,
            Role.OWNER,
            true
        );

        users[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = User (
            "Seller",
            "",
            0x1841d653f9c4edda9d66a7e7737b39763d6bd40f569a3ec6859d3305b72310e6,
            0x64e604787cbf194841e7b68d7cd28786f6c9a0a3ab9f8b0a0e87cb4387ab0107,
            Role.SELLER,
            Role.SELLER,
            true
        );

        users[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = User (
            "Buyer",
            "",
            0x1841d653f9c4edda9d66a7e7737b39763d6bd40f569a3ec6859d3305b72310e6,
            0x64e604787cbf194841e7b68d7cd28786f6c9a0a3ab9f8b0a0e87cb4387ab0107,
            Role.BUYER,
            Role.BUYER,
            true
        );
    }

}
