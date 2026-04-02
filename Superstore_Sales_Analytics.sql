Drop Database Sales_AnalyticsDB

CREATE DATABASE Sales_AnalyticsDB
GO
USE Sales_AnalyticsDB

SELECT name FROM sys.databases;


--Superstore Flat Table

Select Top 10 * From Superstore

--will split the data in 4 tables (Star Schema)

--Customers  → Orders → Order_Items ← Products

CREATE TABLE Customers (
    Customer_ID VARCHAR(20) PRIMARY KEY,
    Customer_Name VARCHAR(100),
    Segment VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Region VARCHAR(50)
)

CREATE TABLE Products (
    Product_ID VARCHAR(20) PRIMARY KEY,
    Category VARCHAR(50),
    Sub_Category VARCHAR(50),
    Product_Name VARCHAR(200)
)

CREATE TABLE Orders (
    Order_ID VARCHAR(20) PRIMARY KEY,
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(50),
    Customer_ID VARCHAR(20),
    FOREIGN KEY (Customer_ID)
        REFERENCES Customers(Customer_ID)
)
	
CREATE TABLE Order_Items (
    Order_Item_ID INT IDENTITY(1,1) PRIMARY KEY,
    Order_ID VARCHAR(20),
    Product_ID VARCHAR(20),
    Sales DECIMAL(10,2),
    Quantity INT,
    Profit DECIMAL(10,2),
    Discount DECIMAL(5,2),
    FOREIGN KEY (Order_ID)
        REFERENCES Orders(Order_ID),
    FOREIGN KEY (Product_ID)
        REFERENCES Products(Product_ID)
)

SELECT *
FROM Superstore
WHERE Customer_ID = 'AA-10315'

INSERT INTO Customers
(Customer_ID, Customer_Name, Segment, City, State, Region)
SELECT
    Customer_ID,
    MAX(Customer_Name),
    MAX(Segment),
    MAX(City),
    MAX(State),
    MAX(Region)
FROM Superstore
GROUP BY Customer_ID


INSERT INTO Products
SELECT DISTINCT
    Product_ID,
   Max(Category),
   Max(Sub_Category),
   Max(Product_Name)
FROM Superstore
Group By Product_ID

INSERT INTO Orders
SELECT DISTINCT
    Order_ID,
    Max(Order_Date),
    Max(Ship_Date),
    Max(Ship_Mode),
    Max(Customer_ID)
FROM Superstore
Group By Order_ID


INSERT INTO Order_Items (
    Order_ID,
    Product_ID,
    Sales,
    Quantity,
    Profit,
    Discount
)
SELECT
    Order_ID,
    Product_ID,
    Sales,
    Quantity,
    Profit,
    Discount
FROM Superstore;

SELECT * FROM Customers
SELECT * FROM Products
SELECT * FROM Orders
SELECT * FROM Order_Items

--Phase 1
--Layer 1 — Core Business KPIs (Foundation)

--Total Revenue, Profit, Quantity

Select Sum(Sales) As Total_Revenue,
		Sum(Quantity) As Total_Quantity,
		Sum(Profit) As Total_Profit
		From Order_Items

--Monthly Revenue Trend
--My Way
Select Format(O.Order_Date, 'yyyy-MM') As Order_Month,
Sum(OI.Sales) As Monthly_Revenue
From Orders O
Join Order_Items OI
On O.Order_ID = OI.Order_ID
Group By Format(O.Order_Date, 'yyyy-MM')
Order By Order_Month, Monthly_Revenue

--Professional way

Select Month(O.Order_Date) As Order_Month,
Year(O.Order_Date) As Order_Year,
Sum(OI.Sales) As Monthly_Revenue
From Orders O
Join Order_Items OI
On O.Order_ID = OI.Order_ID
Group By Year(O.Order_Date), Month(O.Order_Date)
Order By Order_Year, Order_Month

--Top 10 Customers by Revenue

Select Top 10 C.Customer_ID, C.Customer_Name,
Sum(OI.Sales) As Revenue
From Order_Items OI
Join Orders O
On O.Order_ID = OI.Order_ID
Join Customers C
On C.Customer_ID = O.Customer_ID
Group By C.Customer_ID, C.Customer_Name
Order By Revenue Desc

--Professional Way

Select * 
From (
	Select C.Customer_ID, C.Customer_Name,
	Sum(OI.Sales) As Revenue,
	Rank() Over(Order By Sum(OI.Sales) Desc) As Customer_Rank
	From Order_Items OI
	Join Orders O
	On O.Order_ID = OI.Order_ID
	Join Customers C
	On C.Customer_ID = O.Customer_ID
	Group By C.Customer_ID, C.Customer_Name
	) t
	Where Customer_Rank <= 10

--Revenue by Category

Select P.Category,
Sum(OI.Sales) As Revenue
From Products P
Join Order_Items OI
On P.Product_ID = OI.Product_ID
Group By P.Category
Order By Revenue Desc

--With Ranking

Select P.Category,
Sum(OI.Sales) As Revenue,
Rank() Over(Order By Sum(OI.Sales) Desc) As Total_Revenue
From Products P
Join Order_Items OI
On P.Product_ID = OI.Product_ID
Group By P.Category

--Phase 2
--Layer 2 — Customer Analytics

--Customer Lifetime Value (total revenue per customer)

Select C.Customer_ID, C.Customer_Name,
Sum(OI.Sales) As Customer_Lifetime_Value
From Customers C
Join Orders O
On C.Customer_ID = O.Customer_ID
Join Order_Items OI
On O.Order_ID = OI.Order_ID
Group By C.Customer_ID, C.Customer_Name
Order By Customer_Lifetime_Value Desc

--Repeat Customers

Select C.Customer_ID, C.Customer_Name,
Count(Distinct O.Order_ID) As Order_Count
From Customers C
Join Orders O
On C.Customer_ID= O.Customer_ID
Group By C.Customer_ID, C.Customer_Name
Having Count(Distinct O.Order_ID) > 1
Order By Order_Count Desc

--Customer First & Last Order

Select C.Customer_ID, C.Customer_Name,
Min(O.Order_Date) As First_Order,
Max(O.Order_Date) As Last_Order
From Customers C
Join Orders O
ON C.Customer_ID = O.Customer_ID
Group By C.Customer_ID, C.Customer_Name 

--Customer First & Last Order with customer lifespan

Select C.Customer_ID, C.Customer_Name,
Min(O.Order_Date) As First_Order,
Max(O.Order_Date) As Last_Order,
Datediff(Day, Min(O.Order_Date), Max(O.Order_Date)) As Customer_Lifespan_Days
From Customers C
Join Orders O
ON C.Customer_ID = O.Customer_ID
Group By C.Customer_ID, C.Customer_Name
Order By Customer_Lifespan_Days Desc

--Layer 3 — Advanced Analytics (Window Functions)
--Rank Customers by Revenue

Select C.Customer_ID, C.Customer_Name,
Sum(OI.Sales) As Revenue,
Rank () Over(Order By Sum(OI.Sales) Desc) As Revenue_Rank
From Customers C
Join Orders O
On C.Customer_ID = O.Customer_ID
Join Order_Items OI
On OI.Order_ID = O.Order_ID
Group By C.Customer_ID, C.Customer_Name
Order By Revenue_Rank Desc

--Running Total of Sales by Date

With Daily_Sales As(
Select O.Order_Date,
Sum(OI.Sales) As Daily_Revenue
From Orders O
Join Order_Items OI
On O.Order_ID = OI.Order_ID
Group By O.Order_Date
)

Select Order_Date, Daily_Revenue,
	Sum(Daily_Revenue) Over (
	Order By Order_Date Rows Between Unbounded Preceding and Current Row
	) As Running_Total_Sales
From Daily_Sales
Order By Order_Date

--Compare Customer Revenue vs Average

Select C.Customer_ID, C.Customer_Name,
Sum(OI.Sales) As Cust_Revenue,
Avg(OI.Sales) As Avg_Revenue
From Customers C
Join Orders O
On C.Customer_ID = O.Customer_ID
Join Order_Items OI
On O.Order_ID = OI.Order_ID
Group By C.Customer_ID, C.Customer_Name
Order By Cust_Revenue Desc, Avg_Revenue Desc

--

WITH Customer_Revenue AS (
    SELECT 
        C.Customer_ID,
        C.Customer_Name,
        SUM(OI.Sales) AS Total_Revenue
    FROM Customers C
    JOIN Orders O
        ON C.Customer_ID = O.Customer_ID
    JOIN Order_Items OI
        ON O.Order_ID = OI.Order_ID
    GROUP BY 
        C.Customer_ID,
        C.Customer_Name
)

SELECT *,
       CASE 
           WHEN Total_Revenue > Avg_Revenue THEN 'Above Average'
           WHEN Total_Revenue < Avg_Revenue THEN 'Below Average'
           ELSE 'Average'
       END AS Revenue_Category
FROM (
    SELECT 
        Customer_ID,
        Customer_Name,
        Total_Revenue,
        AVG(Total_Revenue) OVER () AS Avg_Revenue
    FROM Customer_Revenue
) t
ORDER BY Total_Revenue DESC

--Layer 4 — Business Insights (Real Company Logic)

--Best Selling Product per Category

With Product_Sales As (
Select P.Category, P.Product_Name,
Sum(OI.Sales) As Total_Revenue
From Products P
Join Order_Items OI
On P.Product_ID = OI.Product_ID
Group By P.Category, P.Product_Name
)
Select *
From (
	Select Category, Product_Name, Total_Revenue,
	Rank() Over (Partition By Category Order By Total_Revenue Desc) As Rank_In_Category
	From Product_Sales
) t
Where Rank_In_Category = 1
Order By Category
	
--Monthly Growth Rate

With Monthly_Sales As (
Select Format(O.Order_Date, 'yyyy-MM') As Order_Month,
Sum(OI.Sales) As Monthly_Revenue
From Orders O
Join Order_Items OI
On O.Order_ID = OI.Order_ID
Group By Format(O.Order_Date, 'yyyy-MM')
)
Select
	Order_Month, Monthly_Revenue,
	Lag(Monthly_Revenue) Over (Order By Order_Month) As Previous_Month_Revenue,

	Case
	When Lag(Monthly_Revenue) Over (Order By Order_Month) Is Null
	Then Null
	Else
	((Monthly_Revenue - Lag(Monthly_Revenue) Over (Order By Order_Month)) * 100.0
	/Lag(Monthly_Revenue) Over (Order By Order_Month))
	End As Growth_Percentage
From Monthly_Sales
Order By Order_Month