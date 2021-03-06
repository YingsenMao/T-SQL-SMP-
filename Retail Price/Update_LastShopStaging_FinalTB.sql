USE [DM_SMP_Pricing]
GO
/****** Object:  StoredProcedure [db_datawriter].[Update_Retail_LastPRS_FinalTB]    Script Date: 5/19/2017 8:42:16 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [db_datawriter].[Update_Retail_LastPRS_FinalTB]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	TRUNCATE TABLE PRS_Retail_LastShop_Staging;

	DECLARE @RowsToProcess int
	DECLARE @CurrentRow int
	DECLARE @SelectedRetailer VARCHAR(50)
	DECLARE @SelectedXMfg VARCHAR(3)  
	DECLARE @SQLQuery_2 VARCHAR(MAX)  

	DECLARE @table1 TABLE (RowID int not null primary key identity(1,1), Retail_XMfg VARCHAR(3), RetailerName VARCHAR(50) )

	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('ADV', 'AdvanceAutoParts');
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('AMZ', 'Amazon');
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('AZR', 'Autozone');
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('JEG', 'Jegs');
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('NAP', 'Napaonline');
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('ORY', 'OReillyAuto');	
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('PAG', 'Partsgeek');	
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('PBR', 'Pepboys');	
	INSERT INTO @table1(Retail_XMfg, RetailerName) VALUES('ROC', 'Rockauto');


	SET @RowsToProcess = (SELECT COUNT(*) FROM @table1);

	SET @CurrentRow=0
	WHILE @CurrentRow < @RowsToProcess
	BEGIN
		SET @CurrentRow=@CurrentRow+1

		SET @SelectedRetailer = (SELECT RetailerName FROM @table1 WHERE RowID = @CurrentRow)
		SET @SelectedXMfg = (SELECT Retail_XMfg FROM @table1 WHERE RowID = @CurrentRow)
		SET @SQLQuery_2 = 
				'WITH C AS
				(
				SELECT CLEANPRODUCTNUMBER, CLEANPRODUCTBRAND,
				RIGHT(CAST(YEAR(MAX(DATE_CREATED)) AS CHAR(4)), 2) + RIGHT(''0'' + RTRIM(MONTH(MAX(DATE_CREATED))), 2) AS LastShop
				FROM PRS_Import_' + @SelectedRetailer + ' WHERE PRICE > 0 GROUP BY CLEANPRODUCTNUMBER, CLEANPRODUCTBRAND
				),
				C_1 AS
				(
				SELECT t0.*, t1.LastShop FROM PRS_Import_' + @SelectedRetailer + ' AS t0 INNER JOIN C AS t1
				ON t0.CLEANPRODUCTNUMBER = t1.CLEANPRODUCTNUMBER 
				AND t0.CLEANPRODUCTBRAND = t1.CLEANPRODUCTBRAND 
				AND RIGHT(CAST(YEAR(DATE_CREATED) AS CHAR(4)), 2) + RIGHT(''0'' + RTRIM(MONTH(DATE_CREATED)), 2) 
				= t1.LastShop WHERE t0.PRICE > 0
				)
				INSERT INTO PRS_Retail_LastShop_Staging(Retai_Xmfg, MfgPart, MfgBrand, MinPrice,  MaxPrice, AvgPrice, AvgCore, ShopCnt, LastShop)
				SELECT RETAIL_XMFG, CLEANPRODUCTNUMBER AS MfgPart, CLEANPRODUCTBRAND AS MfgBrand, MIN(PRICE) AS MinPrice, MAX(PRICE) AS MaxPrice, AVG(PRICE) 
				AS AvgPrice, AVG(COREPRICE) AS AvgCore, COUNT(DISTINCT ZIPCODE) AS ShopCnt, LastShop 
				FROM C_1 GROUP BY RETAIL_XMFG, CLEANPRODUCTNUMBER, CLEANPRODUCTBRAND, LastShop;'

		--print @SQLQuery_2
		--do your thing here--
		EXEC(@SQLQuery_2)
	END;


	---------------------------------------------------------------Final PS----------------------------------
	DROP TABLE DM_SMP_Pricing.dbo.PRS_Retail_TB;
	WITH C_0 AS 
	(
		SELECT t1.XMfg, t2.FS_Part AS BasePart, t0.XMfgPart AS BrandPart
		FROM DW_Marketing.dbo.DW_XRF_PricingNEW AS t0 INNER JOIN
		DW_Marketing.dbo.DW_XRF_PriceSheets AS t1 ON t0.psID = t1.psID INNER JOIN
		DW_Marketing.dbo.DW_XRF_Xref AS t2 ON t0.XMfgPart = t2.CompPart AND t1.XMfg = t2.XMfg
		WHERE (t1.XMfg IN ('HDC', 'ACI', 'PRO')) AND (t1.SheetRank = 1)
		GROUP BY t1.XMfg, t2.FS_Part, t0.XMfgPart
	),
	C_1 AS
	(
		select t0.BasePart, t1.XMfg, t1.BrandPart from DW_Marketing.dbo.DW_BaseData_Ranks AS t0
		LEFT JOIN C_0 AS t1
		ON t0.BasePart = t1.BasePart
		where LFC like '2%' or LFC like '3%' or LFC like '4%'
	),
	C_2 AS
	(
		SELECT BasePart, 
		MAX(CASE [XMfg] WHEN 'ACI' THEN BrandPart ELSE NULL END) AS ACI, 
		MAX(CASE [XMfg] WHEN 'PRO' THEN BrandPart ELSE NULL END) AS PRO, 
		MAX(CASE [XMfg] WHEN 'HDC' THEN BrandPart ELSE NULL END) AS Hayden
		FROM C_1 GROUP BY BasePart
	)
	SELECT t2.FS_Part AS BasePart, t3.ACI, t3.PRO AS ProSource, t3.Hayden, t1.RETAIL_XMFG, t1.ALTXMFG, t1.PRODUCTNUMBER AS MfgPart, t1.PRODUCTBRAND AS MfgBrand, t1.PRODUCTNAME AS MfgDescription, 
	t0.MinPrice, t0.MaxPrice, t0.AvgPrice, t0.AvgCore, t0.ShopCnt, t0.LastShop, t2.D_I, t1.CLEANPRODUCTNUMBER AS CleanMfgPart, t1.CLEANPRODUCTBRAND AS CMfgPart
	INTO DM_SMP_Pricing.dbo.PRS_Retail_TB
	FROM dbo.PRS_Retail_LastShop_Staging AS t0 
	INNER JOIN dbo.PRS_Retail_Parts_List AS t1 
	ON t0.Retai_Xmfg = t1.RETAIL_XMFG AND t0.MfgPart = t1.CLEANPRODUCTNUMBER 
	AND t0.MfgBrand = t1.PRODUCTBRAND INNER JOIN
	DW_Marketing.dbo.DW_XRF_Xref AS t2 ON t1.CLEANPRODUCTNUMBER = t2.CompClean AND t1.ALTXMFG = t2.XMfg 
	INNER JOIN C_2 AS t3 
	ON t2.FS_Part = t3.BasePart
	WHERE (t1.Y_N = 'Y') AND (t0.MaxPrice > 0)
END

