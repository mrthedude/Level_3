## CollateralLending: LEVEL 3 

**This is a basic lending and borrowing contract designed to accept/use a specified ERC20 token and has some liquidation functionality.**


The main contracts of this repo are:

-   **token.sol**: The ERC20 token that is deployed in tandem with the lending/borrowing contract and is the only ERC20 token that is compatible with the contract

-   **collateralLending.sol**: A basic lending and borrowing contract with some liquidation mechanics, designed to be compatible only with the `token.sol` ERC20 contract

-   **HelperConfig.s.sol**: Used to help automate deployment

-   **DeploymentScripts.s.sol**: Deployment contract used to deploy both the collateralLending.sol and token.sol contracts 

-   **testCollateralLending.t.sol**: Tests file for all the above listed contracts and their functionalities