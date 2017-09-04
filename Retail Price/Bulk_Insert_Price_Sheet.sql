USE [DW_Marketing]
GO
/****** Object:  StoredProcedure [dbo].[Bulk_Insert_PriceSheet]    Script Date: 9/4/2017 5:53:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[Bulk_Insert_PriceSheet]
	@filename varchar(100)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	Declare @sql varchar(1000)--, @filename varchar(100)
	
	truncate table DW_XRF_Pricing_WD_Load
	--set @filename = '\\LEWDWSQL01\CatData\Import\PriceSheet_4335_07292016.txt'
	set @sql = 'Bulk Insert DW_Marketing.dbo.DW_XRF_Pricing_WD_Load From ''' + @filename + ''' WITH ( FIRSTROW = 2, MAXERRORS = 0, FIELDTERMINATOR = ''\t'', ROWTERMINATOR = ''\n'' )'
	
	Exec(@sql)

	update  DW_XRF_Pricing_WD_Load
	set POP_Code = ltrim(rtrim(pop_code))

--********************************************************************* Downstream Pricing Setup **************************************************************************
if exists (select * from sys.objects where name = 'temp_price_load' and type = 'u')
    begin
		drop table [dbo].[temp_price_load]
	end

CREATE TABLE [dbo].[temp_price_load](
	[Brand] [varchar](3) NOT NULL,
	[Xmfg] [nvarchar](6) not null,
	[Cust_Part_Number] [nvarchar](20) NOT NULL,
	[Price_Type] [varchar](25) NOT NULL,
	[FS_WD] [float] NOT NULL,
	[PriceGroup] [varchar](20) NOT NULL,
	[CalcPrice] [float] NULL,
	[Percent_of_WD] [float] NULL,
	[Percent_of_Gross] [Float] NULL,
	[PriceNet] [float] null,
	[LoadDate] [datetime] NOT NULL,
	[PriceList] [float] NULL,
	[PriceJobber] [float] NULL,
	[PriceDealer] [float] NULL,
	[POP] [varchar](10) null,
	[ChangeCode] [varchar](100) null,
	[CorePrice] [float] null,
	[Price_Sheet_Number] [varchar](15) null,
	[Effective_Date] [date] null
) ON [PRIMARY]


-- No Special routine
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.Cust_Part_Number, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, DW_XRF_Pricing_WD_Load.Gross_Price AS FS_WD, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, 
                         ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2) AS CalcPrice, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, 
                         DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         dbo.DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BASE_WD
WHERE        (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD IS NOT NULL) AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine IS NULL OR
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine = 0) AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y')
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DW_XRF_Pricing_WD_Load.Cust_Part_Number, DW_XRF_Pricing_WD_Load.Gross_Price, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2), DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2), 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, 
                         DW_XRF_Pricing_WD_Load.xmfg, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type

-- Ceiling Routine
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg,  
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, DW_XRF_Pricing_WD_Load.Gross_Price AS FS_WD, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7,
                          2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 2)) * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)) 
                         / CAST(.05 AS numeric(2, 2))) ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)), 2) END AS CalcPrice, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
						 DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Base_WD
WHERE        (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'Ceiling') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD IS NOT NULL) AND 
                         (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y') 
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DW_XRF_Pricing_WD_Load.Cust_Part_Number, 
                         DW_XRF_Pricing_WD_Load.Gross_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, 
                         CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 2)) 
                         * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)) / CAST(.05 AS numeric(2, 2))) 
                         ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)), 2) END, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2), 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2), 
						 DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.xmfg, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date,DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type


-- Washer Pump routine added on 2/23/2017--
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, 
                         DW_XRF_Pricing_WD_Load.Gross_Price AS FS_WD, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, 
                         ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2) AS CalcPrice, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         dbo.DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BASE_WD INNER JOIN
                         dbo.DW_BaseData_Ranks ON dbo.DW_XRF_Pricing_WD_Load.Cust_Part_Number = dbo.DW_BaseData_Ranks.BasePart
WHERE        (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine IS NULL OR
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine = 1) AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD IS NOT NULL) AND 
                         (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'Washer_Pump') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y') AND 
                         (dbo.DW_BaseData_Ranks.Group1 = 'Washer Pump')
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DW_XRF_Pricing_WD_Load.Cust_Part_Number, DW_XRF_Pricing_WD_Load.Gross_Price, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2), DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2), 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.xmfg
						 , DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type


-- Heater Cores routine added on 2/23/2017--
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, 
                         DW_XRF_Pricing_WD_Load.Gross_Price AS FS_WD, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, 
                         ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2) AS CalcPrice, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         dbo.DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BASE_WD INNER JOIN
                         dbo.DW_BaseData_Ranks ON dbo.DW_XRF_Pricing_WD_Load.Cust_Part_Number = dbo.DW_BaseData_Ranks.BasePart
WHERE        (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine IS NULL OR
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine = 1) AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD IS NOT NULL) AND 
                         (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'Heater_Cores') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y') AND 
                         (dbo.DW_BaseData_Ranks.Group1 = 'Heater Cores')
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DW_XRF_Pricing_WD_Load.Cust_Part_Number, DW_XRF_Pricing_WD_Load.Gross_Price, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2), DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2), 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.xmfg
						 , DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type


-- Balkamp routine added on 2/23/2017--
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, 
                         DW_XRF_Pricing_WD_Load.Gross_Price AS FS_WD, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, 
                         ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2) AS CalcPrice, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         dbo.DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BASE_WD INNER JOIN
                         dbo.DW_BaseData_Ranks ON dbo.DW_XRF_Pricing_WD_Load.Cust_Part_Number = dbo.DW_BaseData_Ranks.BasePart
WHERE        (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine IS NULL OR
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine = 1) AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD IS NOT NULL) AND 
                         (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'Balkamp') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y') AND 
                         (dbo.DW_BaseData_Ranks.Group1 IN ('Blower Motor Wheels', 'Blower Motors', 'Cooling Fan Assemblies', 'Cooling Fan Motors', 'Engine Coolant Components', 'Fans, Spacers And Blades', 'Heater Fittings', 
                         'Heater Valves', 'Oil Coolers', 'Window Motor'))
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DW_XRF_Pricing_WD_Load.Cust_Part_Number, DW_XRF_Pricing_WD_Load.Gross_Price, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)), 2), DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2), 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.xmfg
						 , DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type


-- UniSelect Non A08
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, 
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, DW_XRF_Pricing_WD_Load.Gross_Price AS FS_WD, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7,
                          2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 2)) * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)) 
                         / CAST(.05 AS numeric(2, 2))) ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)), 2) END AS CalcPrice, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                         DW_TAX_PDM0 INNER JOIN
                         DW_TAX_PDM1 ON DW_TAX_PDM0.PDM1 = DW_TAX_PDM1.PDM1 INNER JOIN
                         DW_TAX_PDM1_JDESetup ON DW_TAX_PDM1.PDM1 = DW_TAX_PDM1_JDESetup.PDM1 ON 
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number = DW_TAX_PDM0.BasePart INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Base_WD
WHERE        (DW_TAX_PDM1_JDESetup.SRP3 <> 'A08') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'NON A08') AND 
                         (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y')
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DW_XRF_Pricing_WD_Load.Cust_Part_Number, 
                         DW_XRF_Pricing_WD_Load.Gross_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, 
                         CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 2)) 
                         * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)) / CAST(.05 AS numeric(2, 2))) 
                         ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)), 2) END, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2), 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2), 
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.xmfg
						 , DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type

-- UniSelect A08
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, 
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, DW_XRF_Pricing_WD_Load.Gross_Price AS FS_WD, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(HaydenPrice.Price AS numeric(7, 2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 2)) * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(HaydenPrice.Price AS numeric(7, 2)) / CAST(.05 AS numeric(2, 2))) ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(HaydenPrice.Price AS numeric(7, 2)), 2) END AS CalcPrice, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(HaydenPrice.Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
                         ROUND(HaydenPrice.Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(HaydenPrice.Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
						 DW_XRF_Pricing_WD_Load.POP_Code, 
                         DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                         DW_TAX_PDM0 INNER JOIN
                         DW_TAX_PDM1 ON DW_TAX_PDM0.PDM1 = DW_TAX_PDM1.PDM1 INNER JOIN
                         DW_TAX_PDM1_JDESetup ON DW_TAX_PDM1.PDM1 = DW_TAX_PDM1_JDESetup.PDM1 ON 
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number = DW_TAX_PDM0.BasePart INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Base_WD LEFT OUTER JOIN
                             (SELECT        HaydenPrice_1.Brand, HaydenPrice_1.BasePart, DW_XRF_Xref.FS_Part, HaydenPrice_1.PriceGroup, HaydenPrice_1.Price, HaydenPrice_1.BegJulian,
                                                          HaydenPrice_1.EndJulian, HaydenPrice_1.CreditJulian, HaydenPrice_1.ChangeUser, HaydenPrice_1.ChangeDate
                               FROM            (SELECT        LTRIM(LEFT(F4106_PriceFile.BPLITM, 3)) AS Brand, CASE WHEN SUBSTRING(F4106_PriceFile.BPLITM, 4, 1) 
                                                                                   <> 0 THEN RTRIM(SUBSTRING(F4106_PriceFile.BPLITM, 4, 25)) ELSE RTRIM(SUBSTRING(F4106_PriceFile.BPLITM, 5, 25)) 
                                                                                   END AS BasePart, F4094_PriceFileGroup.KICPGP AS PriceGroup, F4106_PriceFile.BPUPRC * .0001 AS Price, 
                                                                                   F4106_PriceFile.BPEFTJ AS BegJulian, F4106_PriceFile.BPEXDJ AS EndJulian, F4106_PriceFile.BPACRD AS CreditJulian, 
                                                                                   F4106_PriceFile.BPUSER AS ChangeUser, F4106_PriceFile.BPUPMJ AS ChangeDate
                                                         FROM            F4094_PriceFileGroup INNER JOIN
                                                                                   F4106_PriceFile ON F4094_PriceFileGroup.KIICID = F4106_PriceFile.BPICID
                                                         WHERE        (LTRIM(LEFT(F4106_PriceFile.BPLITM, 3)) = '625') AND (F4094_PriceFileGroup.KICPGP = N'HYFILTR')) 
                                                         AS HaydenPrice_1 LEFT OUTER JOIN
                                                             (SELECT        CompPart, FS_Part
                                                               FROM            DW_XRF_Xref AS DW_XRF_Xref_1
                                                               WHERE        (XMfg = 'HDC')
                                                               GROUP BY CompPart, FS_Part) AS DW_XRF_Xref ON HaydenPrice_1.BasePart = DW_XRF_Xref.CompPart) AS HaydenPrice ON 
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number = HaydenPrice.FS_Part
WHERE        (NOT (CASE WHEN HaydenPrice.Price > 10 THEN .05 * ceiling(TCD_MarketPricing_Calculations.Percent_of_WD * HaydenPrice.Price / .05) 
                         ELSE ROUND(TCD_MarketPricing_Calculations.Percent_of_WD * HaydenPrice.Price, 2) END IS NULL)) AND (DW_TAX_PDM1_JDESetup.SRP3 = 'A08') AND 
                         (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'A08') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y')
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DW_XRF_Pricing_WD_Load.Cust_Part_Number, 
                         DW_XRF_Pricing_WD_Load.Gross_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, 
                         CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(HaydenPrice.Price AS numeric(7, 2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 
                         2)) * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(HaydenPrice.Price AS numeric(7, 2)) / CAST(.05 AS numeric(2, 2))) 
                         ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(HaydenPrice.Price AS numeric(7, 2)), 2) END, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
						 ROUND(HaydenPrice.Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2), 
                         ROUND(HaydenPrice.Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2), 
                         ROUND(HaydenPrice.Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2), 
						 DW_XRF_Pricing_WD_Load.POP_Code, 
                         DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.xmfg
						 , DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date,DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type

-- UOM
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, 
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, DW_XRF_Pricing_WD_Load.Gross_Price * CAST(UOMParts.Info AS float) AS FS_WD, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7,
                          2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 2)) * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)) 
                         / CAST(.05 AS numeric(2, 2)) * CAST(UOMParts.Info AS numeric(5, 2))) ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(Gross_Price AS numeric(7, 2)), 2 * CAST(UOMParts.Info AS numeric(5, 2))) END AS CalcPrice, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, 
                         { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
						 DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                             (SELECT        Basepart, Info
                               FROM            DW_PIE_Superset
                               WHERE        (Type = N'Standard/MinimumOrderQuantity')
                               GROUP BY Basepart, Info) AS UOMParts ON DW_XRF_Pricing_WD_Load.Cust_Part_Number = UOMParts.Basepart INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Base_WD
WHERE        (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'UOM') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y')
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, CASE WHEN ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7,
                          2)), 2) > 9.99 THEN CAST(.05 AS numeric(2, 2)) * ceiling(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) * CAST(Gross_Price AS numeric(7, 2)) 
                         / CAST(.05 AS numeric(2, 2)) * CAST(UOMParts.Info AS numeric(5, 2))) ELSE ROUND(CAST(TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(Gross_Price AS numeric(7, 2)), 2 * CAST(UOMParts.Info AS numeric(5, 2))) END, DW_XRF_Pricing_WD_Load.Cust_Part_Number, 
                         DW_XRF_Pricing_WD_Load.Gross_Price * CAST(UOMParts.Info AS float), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) , 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) , 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) , 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand,
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.xmfg, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg
						 , DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date,DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type

-- No Ceiling UOM
INSERT INTO temp_price_load
                         (Brand, Xmfg, Cust_Part_Number, Price_Type, FS_WD, PriceGroup, CalcPrice, Percent_of_WD, LoadDate, PriceList, PriceJobber, PriceDealer, POP, 
                         ChangeCode, CorePrice, Price_Sheet_Number, Effective_Date)
SELECT        DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, 
                         DW_XRF_Pricing_WD_Load.Cust_Part_Number, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type, DW_XRF_Pricing_WD_Load.Gross_Price * CAST(UOMParts.Info AS float) AS FS_WD, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)) * CAST(UOMParts.Info AS numeric(5, 2)), 2) AS CalcPrice, 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, { fn NOW() } AS Expr1, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) AS PriceList, 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) AS PriceJobber, 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) AS PriceDealer, 
						 DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date
FROM            DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice INNER JOIN
                         DW_XRF_Pricing_WD_Load ON DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.PopCode = DW_XRF_Pricing_WD_Load.POP_Code INNER JOIN
                             (SELECT        Basepart, Info
                               FROM            DW_PIE_Superset
                               WHERE        (Type = N'Standard/MinimumOrderQuantity')
                               GROUP BY Basepart, Info) AS UOMParts ON DW_XRF_Pricing_WD_Load.Cust_Part_Number = UOMParts.Basepart INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON DW_XRF_Pricing_WD_Load.xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Base_WD
WHERE        (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.SpecialPriceRoutine_Note = N'No_Ceiling_UOM') AND (DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.BrandType = 'Y')
GROUP BY DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.PriceGroup, ROUND(CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD AS numeric(5, 4)) 
                         * CAST(DW_XRF_Pricing_WD_Load.Gross_Price AS numeric(7, 2)) * CAST(UOMParts.Info AS numeric(5, 2)), 2), DW_XRF_Pricing_WD_Load.Cust_Part_Number, 
                         DW_XRF_Pricing_WD_Load.Gross_Price * CAST(UOMParts.Info AS float), 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Multiplier, 2) , 
						 ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber, 2) , 
                         ROUND(DW_XRF_Pricing_WD_Load.Gross_Price * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Jobber * DM_SMP_Pricing.dbo.TCD_MarketPricing_ListPrice.Dealer, 2) , 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_WD, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Brand,  
                         DW_XRF_Pricing_WD_Load.POP_Code, DW_XRF_Pricing_WD_Load.Change_Code, DW_XRF_Pricing_WD_Load.Core_Price, 
                         DW_XRF_Pricing_WD_Load.xmfg, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg, DW_XRF_Pricing_WD_Load.Price_Sheet_Number, DW_XRF_Pricing_WD_Load.Effective_Date, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Price_Type
ORDER BY DW_XRF_Pricing_WD_Load.Cust_Part_Number


--Update Percent of Gross in temp-- Added by Daniel on 8/29/2017
UPDATE t0
SET t0.PriceNet = ROUND(CAST(t0.CalcPrice AS numeric(7, 2)) * CAST(t1.Percent_of_Gross AS numeric(7, 2)), 2), t0.Percent_of_Gross = t1.Percent_of_Gross
FROM dbo.temp_price_load AS t0 INNER JOIN
DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations AS t1
ON t0.Xmfg = t1.xmfg 
AND t0.Brand = t1.Brand
AND t0.PriceGroup = t1.PriceGroup
WHERE t1.Percent_of_Gross IS NOT NULL;


--UPDATE       dbo.temp_price_load
--SET                PriceNet = ROUND(CAST(dbo.temp_price_load.CalcPrice AS numeric(7, 2)) * CAST(DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_Gross AS numeric(7, 2)), 2), Percent_of_Gross = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_Gross
--FROM            dbo.temp_price_load INNER JOIN
--                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON dbo.temp_price_load.Xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg


--SELECT        dbo.temp_price_load.CalcPrice, dbo.temp_price_load.FS_WD, dbo.temp_price_load.Percent_of_Gross, DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.Percent_of_Gross AS Expr1, 
--                         dbo.temp_price_load.Brand, dbo.temp_price_load.Xmfg, dbo.temp_price_load.Cust_Part_Number, dbo.temp_price_load.Price_Type, dbo.temp_price_load.PriceGroup
--FROM            dbo.temp_price_load INNER JOIN
--                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations ON dbo.temp_price_load.Xmfg = DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations.xmfg
--WHERE        (NOT (dbo.temp_price_load.Percent_of_Gross IS NULL))
--order by CalcPrice 

-- delete parts from marketing pricing matrix that have price changes 
DELETE FROM DM_SMP_Pricing.dbo.TCD_MarketPricing_Parts
FROM            dbo.temp_price_load INNER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Parts ON temp_price_load.Cust_Part_Number = DM_SMP_Pricing.dbo.TCD_MarketPricing_Parts.PartNumber AND 
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Parts.Brand = DM_SMP_Pricing.dbo.TCD_MarketPricing_Parts.Brand AND dbo.temp_price_load.PriceGroup = DM_SMP_Pricing.dbo.TCD_MarketPricing_Parts.PriceGroup

-- Insert downstream pricing
INSERT INTO dm_smp_pricing.dbo.TCD_MarketPricing_Parts
                         (Brand, Xmfg, PartNumber, Price_Type, FS_WD, PriceGroup, CalcPrice, Perecnt_of_WD, PriceDate, ListPrice, JobberPrice, DealerPrice)
SELECT        temp_price_load.Brand, temp_price_load.Xmfg, temp_price_load.Cust_Part_Number, temp_price_load.Price_Type, 
                         temp_price_load.FS_WD, temp_price_load.PriceGroup, temp_price_load.CalcPrice, temp_price_load.Percent_of_WD, temp_price_load.LoadDate, 
                         temp_price_load.PriceList, temp_price_load.PriceJobber, temp_price_load.PriceDealer
FROM            temp_price_load LEFT OUTER JOIN
                         DM_SMP_Pricing.dbo.TCD_MarketPricing_Parts AS TCD_MarketPricing_Parts_1 ON (temp_price_load.Brand = TCD_MarketPricing_Parts_1.Brand) AND 
                         (temp_price_load.PriceGroup = TCD_MarketPricing_Parts_1.PriceGroup) AND temp_price_load.Cust_Part_Number = TCD_MarketPricing_Parts_1.PartNumber
WHERE        (TCD_MarketPricing_Parts_1.Xmfg IS NULL)
GROUP BY temp_price_load.Brand, temp_price_load.Cust_Part_Number, temp_price_load.Price_Type, temp_price_load.FS_WD, 
                         temp_price_load.PriceGroup, temp_price_load.CalcPrice, temp_price_load.Percent_of_WD, temp_price_load.LoadDate, temp_price_load.PriceList, 
                         temp_price_load.PriceJobber, temp_price_load.PriceDealer, temp_price_load.Xmfg


-- TCD_NEW_ITEMS_PRICING -- added on 7/21/2017--
-- remove the any pre-existing prices because of multiple uploads
DELETE t1
FROM DW_Marketing.dbo.temp_price_load AS t0 INNER JOIN
DM_SMP_Pricing.dbo.JDFDTAFS_FIM4106W AS t1 
ON t0.Cust_Part_Number = RIGHT(t1.Item_Num, LEN(t1.Item_Num) - 3) AND 
t0.Brand = t1.Brand AND
t0.PriceGroup = t1.Cust_Group AND
t0.CalcPrice = t1.Price_Per_Unit
Where t1.Uploaded='0';

-- insert into the table with new prices only for brand and pricing groups that needs to be uploaded for new items
INSERT INTO DM_SMP_Pricing.dbo.JDFDTAFS_FIM4106W(Brand, Item_Num, Cust_Group, Price_Per_Unit, Eff_From, Eff_Thru, 
Credit_Price, User_Code, [User_Id], Cust_Num, Cur_Code, UploadedDate)
SELECT t0.Brand, t0.BRAND + Cust_Part_Number, t0.PriceGroup, t0.CalcPrice, t0.Effective_Date, 
'2050-12-30', '', 'LEW', 'OPER', '', 'USD', t0.LoadDate
FROM DW_Marketing.dbo.temp_price_load AS t0
INNER JOIN DM_SMP_Pricing.dbo.TCD_MarketPricing_Calculations AS t1
ON t0.Xmfg = t1.xmfg
AND t0.Brand = t1.Brand
AND t0.PriceGroup = t1.PriceGroup
WHERE ((t1.JDE_Upload = 'Y' AND t0.ChangeCode LIKE '%New Item%') OR
                                         (t1.PriceAdj_Upload = 'Y' AND t0.ChangeCode LIKE '%Price Adjustment%'))

END