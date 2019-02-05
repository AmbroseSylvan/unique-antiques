--Leo Heath, PROG 8080 F/18. Final assignment.

--Sale system for "Unique Antique," an antique and curiosity shop.

--BUSINESS RULES:
--	Customers purchase items at POS.
--	Customers require a member card (Silver, $0.00) before they can make purchases.
--	Customers may purchase a Gold card if they have $100 and enough silver points (GP). These are awarded by the store when certain conditions are met (i.e. made x number of purchases). 
--	Customers may only purchase certain items if they have a gold card. 
--	The system must record customer transaction history.
--	The system must record customer GP balance
--	The system must record inventory
--	The system must filter inventory based on customer member status. 
--	All items are unique. 
--	All items also have a GP price. 
--	All items must be marked with a buyer ID when they are purchased. 
--	Deprecated membership types must still be grandfathered in and honored even if that membership is no longer available. 
--	No returns or refunds. 

CREATE TABLE Memberships (
	ID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	Name VARCHAR(20) NOT NULL,
	Price DECIMAL NOT NULL,
	GP_Price INT NOT NULL
);
	
CREATE TABLE Customers (
	Account INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	Name VARCHAR(100) NOT NULL,
	Member_Level INT NOT NULL,
	GP_Balance INT NULL,
	CONSTRAINT fk_Cust_Level 
		FOREIGN KEY (Member_Level)
		REFERENCES Memberships (ID)
		ON UPDATE CASCADE
);

CREATE TABLE Items (
	ID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	Name VARCHAR(150) NOT NULL UNIQUE,
	Member_Level INT NOT NULL,
	Price DECIMAL NOT NULL,
	GP_Price INT NOT NULL,
	Buyer INT NULL,
	CONSTRAINT fk_Item_Level 
		FOREIGN KEY (Member_Level)
		REFERENCES Memberships (ID)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_Buyer
		FOREIGN KEY (Buyer)
		REFERENCES Customers (Account),
);

CREATE TABLE Orders (
	ID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	Customer_ID INT NOT NULL,
	CONSTRAINT fk_Customer_ID
		FOREIGN KEY (Customer_ID)
		REFERENCES Customers (Account)
);

CREATE TABLE Order_Items (
	ID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	Order_ID INT NOT NULL,
	Item_ID INT NOT NULL,
	CONSTRAINT fk_Order_ID
		FOREIGN KEY (Order_ID)
		REFERENCES Orders (ID),
	CONSTRAINT fk_Item_ID
		FOREIGN KEY (Item_ID)
		REFERENCES Items (ID),
);
GO

--Create membership level.
CREATE PROCEDURE NewMemberLevel @Name VARCHAR(20), @Price INT, @GP_Price INT
AS
INSERT INTO Memberships (Name, Price, GP_Price)
VALUES (@Name, @Price, @GP_Price)
GO

EXEC NewMemberLevel @Name = 'Silver', @Price = 0, @GP_Price = 0;
GO

-- Create new customer. 
CREATE PROCEDURE NewAccount @Name VARCHAR(100), @Member_Level INT
AS
INSERT INTO Customers (Name, Member_Level)
VALUES (@Name, @Member_Level)
GO

-- Update customer member level. 
CREATE PROCEDURE Change_Membership @Account INT, @Next_Level INT, @Cost INT
AS
UPDATE Customers
SET Member_Level = @Next_Level, GP_Balance = GP_Balance - @Cost
WHERE Account = @Account
GO

-- Change GP balance.
CREATE PROCEDURE Change_Balance @Account INT, @Change INT
AS
UPDATE Customers
SET GP_Balance = GP_Balance + @Change
WHERE Account = @Account
GO

-- VALIDATE ITEM AVAILABILITY
-- Does the item already have a buyer?
-- Is customer right level for this item? Param: item ID, customer ID. 
-- Does customer have enough GP? Param: GP balance, GP cost
CREATE PROCEDURE AvailableToCust @Cust_ID INT
AS
SELECT * 
FROM Items
WHERE EXISTS (
	SELECT i.ID
	FROM Items AS i
	FULL OUTER JOIN Customers AS c ON i.Member_Level = c.Member_Level
	WHERE i.Buyer = NULL AND c.Account = @Cust_ID AND c.GP_Balance >= i.GP_Price)
GO

-- Create new Order ID to pass to order items for labeling. 
CREATE PROCEDURE NewOrder @Account INT
AS
INSERT INTO Orders (Customer_ID)
VALUES (@Account)
GO

--Create new order Item.
CREATE PROCEDURE NewOrderItem @Order_ID INT, @Item_ID INT
AS
INSERT INTO Order_Items (Order_ID, Item_ID)
VALUES (@Order_ID, @Item_ID)
GO

-- Change Buyer status of inventoried Item.
CREATE TRIGGER tr_Order_Item ON Order_Items
AFTER INSERT
AS
DECLARE @Cust_ID INT;
SELECT TOP 1 @Cust_ID = Customer_ID
FROM Orders 
ORDER BY ID DESC

DECLARE @Item_ID INT;
SELECT TOP 1 @Item_ID = Item_ID
FROM Order_Items 
ORDER BY ID DESC

DECLARE @Item_Cost INT;
SELECT @Item_Cost = Price
FROM Items
WHERE ID = @Item_ID;

UPDATE Items 
SET Buyer = @Cust_ID
WHERE ID = @Item_ID;
EXEC Change_Balance @Account = @Cust_ID, @Change = @Item_Cost;
GO

-- Select Order Items that match the Order #.
CREATE PROCEDURE ShowOrder @Order_ID INT
AS
SELECT o.ID AS 'Order #', c.Name AS 'Customer', i.Name AS 'Item', i.Price AS 'Price', i.GP_Price AS 'GP Price'
FROM Orders AS o
FULL OUTER JOIN Customers AS c ON o.Customer_ID = c.Account FULL OUTER JOIN Order_Items AS s ON o.ID = s.Order_ID FULL OUTER JOIN Items AS i ON s.ID = i.ID
GO

--    DEMO

--SETUP

--New Item.
INSERT INTO Items (Name, Member_Level, Price, GP_Price)
VALUES ('Tuning Fork, F#', 1, 100, 0);

--New Account.
EXEC NewAccount @Name = 'Sandy Cheeks', @Member_Level = 1;

--Retrieve Customer ID.
DECLARE @Cust INT;
SELECT @Cust = Account
FROM Customers
WHERE Name = 'Sandy Cheeks';

-- Give customer Gold Points
EXEC Change_Balance @Account = @Cust, @Change = 200;

-- Show items available to this customer
EXEC AvailableToCust @Cust_ID = @Cust;

--CREATE ORDER.

-- Create Order ID.
EXEC NewOrder @Account = @Cust;

-- Get newest Order ID
DECLARE @Order INT;
SELECT TOP 1 @Order = ID
FROM Orders 
ORDER BY ID DESC;

-- Get IDs of Items for this order
DECLARE @Item_Name VARCHAR(50);
DECLARE @Item INT;
SET @Item_Name = 'Tuning Fork, F#';
SELECT @Item = ID 
FROM Items 
WHERE Name = @Item_Name;

--Create Order Item.
EXEC NewOrderItem @Order_ID = @Order, @Item_ID = @Item;

--Get complete Order.
EXEC ShowOrder @Order_ID = @Order;

--Try repeating this demo without NEW ITEM and NEW ACCOUNT to see if the system will allow you to buy an item already marked with having a Buyer. 