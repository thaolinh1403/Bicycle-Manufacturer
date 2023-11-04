--Q1: Calc Quantity of items, Sales value & Order quantity by each Subcategory in L12M
select distinct
        format_date('%b %Y', a.ModifiedDate) as period,
        c.Name,
        sum(a.OrderQty) as qty_item,
        sum(a.LineTotal) as total_sales,       
        count(distinct a.SalesOrderID) as order_cnt
from `adventureworks2019.Sales.SalesOrderDetail` as a
left join `adventureworks2019.Production.Product` as b on a.ProductID=b.ProductID
left join `adventureworks2019.Production.ProductSubcategory` as c on cast(b.ProductSubcategoryID as int)=c.ProductSubcategoryID
group by 1, 2
order by 1 desc, 2;

--Q2: Calc % YoY growth rate by SubCategory & release top 3 cat with highest grow rate. Can use metric: quantity_item. Round results to 2 decimal
with cte1 as(
select distinct
        format_date('%Y', a.ModifiedDate) as period,
        c.Name as Name,
        sum(a.OrderQty) as qty_item,
from `adventureworks2019.Sales.SalesOrderDetail` as a
left join `adventureworks2019.Production.Product` as b on a.ProductID=b.ProductID
left join `adventureworks2019.Production.ProductSubcategory` as c on cast(b.ProductSubcategoryID as int)=c.ProductSubcategoryID
group by 2,1
order by 2,1
),
cte2 as (
select cte1.period,
       cte1.Name as Name,
       cte1.qty_item as qty_item,
       lag (qty_item, 1) over(partition by cte1.Name order by cte1.period) as prv_qty 
from cte1
order by 2,1
)
select cte2.Name,
        cte2.qty_item,
        cte2.prv_qty,
        round((cte2.qty_item - cte2.prv_qty)/cte2.prv_qty, 2) as qty_diff
from cte2
where cte2.prv_qty is not null
order by 4 desc, 1
limit 3;

--Q3: Ranking Top 3 TeritoryID with biggest Order quantity of every year. If there's TerritoryID with same quantity in a year, do not skip the rank number
with cte as (
select format_date('%Y', a.ModifiedDate) as yr,
       c.TerritoryID as TerritoryID,
       sum(a.OrderQty) as order_cnt 
from `adventureworks2019.Sales.SalesOrderDetail` as a
left join `adventureworks2019.Sales.SalesOrderHeader` as b on a.SalesOrderID=b.SalesOrderID
left join `adventureworks2019.Sales.Customer` as c on b.CustomerID=c.CustomerID
group by 2, 1
order by 1 desc, 3 desc
)
select *
from (
select cte.yr,
        cte.TerritoryID,
        cte.order_cnt,
        dense_rank () over(partition by cte.yr order by cte.order_cnt desc) as rk
from cte
order by 1 desc)
where rk <=3;

--Q4: Calc Total Discount Cost belongs to Seasonal Discount for each SubCategory
with cte as (
select format_date('%Y', a.ModifiedDate) as year,
       c.Name as Name,
       d.DiscountPct * a.UnitPrice * a.OrderQty as cost
from `adventureworks2019.Sales.SalesOrderDetail` as a
left join `adventureworks2019.Production.Product` as b on a.ProductID=b.ProductID
left join `adventureworks2019.Production.ProductSubcategory` as c on cast(b.ProductSubcategoryID as int)=c.ProductSubcategoryID 
left join `adventureworks2019.Sales.SpecialOffer` as d on a.SpecialOfferID=d.SpecialOfferID
where lower (d.Type) like '%seasonal discount'
)
select cte.year,
       cte.Name,
       sum(cost) as total_cost
from cte
group by 1,2;

--Q5: Retention rate of Customer in 2014 with status of Successfully Shipped (Cohort Analysis)
with cte1 as (
select format_date('%m', ModifiedDate) as Mth_order,
        CustomerID as CustomerID,
      row_number () over (partition by CustomerID order by format_date('%m', ModifiedDate)) as rownumber
FROM `adventureworks2019.Sales.SalesOrderHeader`      
where status =5 
    and format_date('%Y', ModifiedDate) ='2014'
order by 2,1
),
cte2 as (
select Mth_order as Mth_join,
      CustomerID as CustomerID
from cte1
where rownumber=1
group by 2,1
order by 2,1
)
select Mth_join,
      Mth_diff,
      count(Mth_diff) as customer_cnt
from (
select cte1.Mth_order,
        cte1.CustomerID,
        cte2.Mth_join as Mth_join,
        CONCAT('M','-',(cast(cte1.Mth_order as int)-cast(cte2.Mth_join as int))) as Mth_diff
from cte1
left join cte2 on cte1.CustomerID=cte2.CustomerID
group by 2,1,3
order by 2,1
)
group by 1,2
order by 1,2;

--Q6: Trend of Stock level & MoM diff % by all product in 2011. If %gr rate is null then 0. Round to 1 decimal
with cte as (
select b.Name,
       format_date('%m', a.EndDate) as mth,
       format_date('%Y', a.EndDate) as yr, 
       sum(a.StockedQty) as stock_qty
from `adventureworks2019.Production.WorkOrder` as a
left join `adventureworks2019.Production.Product` as b on a.ProductID = b.ProductID
where format_date('%Y', a.EndDate)='2011'
group by 1,2,3
order by 1, 2 desc
)
select *,
      case 
          when cte2.stock_prv is null then 0
          else round((cte2.stock_qty - cte2.stock_prv)*100/cte2.stock_prv, 1)
      end as diff
from (
select cte.Name,
      cte.mth,
      cte.yr,
      cte.stock_qty,
      lead (cte.stock_qty, 1) over(partition by cte.Name order by cte.mth desc) as stock_prv
from cte
order by 1,2 desc) as cte2;

--Q7: Calc MoM Ratio of Stock / Sales in 2011 by product name; Order results by month desc, ratio desc. Round Ratio to 1 decimal
with sale as (
select format_date('%m', c.ModifiedDate) as mth,
       format_date('%Y', c.ModifiedDate) as yr,
       c.ProductID as ProductID,
       b.Name as Name,
       count(distinct c.SalesOrderID) as sale
from `adventureworks2019.Sales.SalesOrderDetail` as c
left join `adventureworks2019.Production.Product` as b on c.ProductID = b.ProductID
where format_date('%Y', c.ModifiedDate) = '2011'
group by 1,2,3,4
order by 1 desc, 4
),
stock as (
select format_date('%m', a.EndDate) as mth,
       format_date('%Y', a.EndDate) as yr,
       a.ProductID as ProductID,
       b.Name as Name, 
       sum(a.StockedQty) as stock
from `adventureworks2019.Production.WorkOrder` as a
left join `adventureworks2019.Production.Product` as b on a.ProductID = b.ProductID
where format_date('%Y', a.EndDate)='2011'
group by 1,2,3,4
order by 1 desc, 2 desc
)
select sale.mth,
        sale.yr,
        sale.ProductID,
        sale.Name,
        sale.sale,
        stock.stock,
        round(stock.stock/sale.sale, 1) as ratio
from sale 
left join stock on sale.ProductID=stock.ProductID
where sale.mth=stock.mth
order by 1 desc,7 desc;

--Q8: No of order and value at Pending status in 2014
select format_date('%Y', OrderDate) as yr,
      Status,
      count(distinct PurchaseOrderID) as Order_cnt,
      sum(TotalDue) as value
from `adventureworks2019.Purchasing.PurchaseOrderHeader`
where status =1
      and format_date('%Y', OrderDate)='2014'
group by 1,2







