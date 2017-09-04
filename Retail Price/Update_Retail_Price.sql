USE [DM_SMP_Pricing]
GO
/****** Object:  StoredProcedure [dbo].[Update_Retail_Price]    Script Date: 9/4/2017 5:48:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[Update_Retail_Price]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS [DM_SMP_Pricing].[dbo].Import_Staging_LastShop;
	DROP TABLE IF EXISTS [DM_SMP_Pricing].[dbo].PRS_Retail_Prices_V3;


	INSERT INTO dbo.PRS_Retail_Brand(RetailXmfg, PRODUCTBRAND)
	SELECT t0.RETAIL_XMFG, t0.PRODUCTBRAND
	FROM PRS_Import_Retail AS t0 LEFT JOIN dbo.PRS_Retail_Brand AS t1
	ON t0.RETAIL_XMFG = t1.RetailXmfg
	AND t0.PRODUCTBRAND = t1.PRODUCTBRAND
	WHERE t0.PRICE > 0 AND t0.PRODUCTBRAND <> '' AND t1.PRODUCTBRAND IS NULL
	GROUP BY t0.RETAIL_XMFG, t0.PRODUCTBRAND;


	WITH C AS
	(
		SELECT RETAIL_XMFG, PRODUCTBRAND, PRODUCTNUMBER, PRODUCTNAME
		FROM PRS_Import_Retail 
		WHERE PRICE > 0 AND PRODUCTNUMBER <> '' AND PRODUCTBRAND <> ''
		GROUP BY RETAIL_XMFG, PRODUCTBRAND, PRODUCTNUMBER, PRODUCTNAME
	),
	C_1 AS
	(
		SELECT t0.RETAIL_XMFG, t0.PRODUCTBRAND, t0.PRODUCTNUMBER, t0.PRODUCTNAME,
		RN = ROW_NUMBER() OVER(PARTITION BY t0.RETAIL_XMFG, t0.PRODUCTBRAND, t0.PRODUCTNUMBER, t0.PRODUCTNAME ORDER BY PRODUCTNAME)
		FROM C AS t0 LEFT JOIN V_Retail_Parts_List AS t1
		ON t0.Retail_Xmfg = t1.RetailXmfg
		AND t0.PRODUCTBRAND = t1.PRODUCTBRAND
		AND t0.PRODUCTNUMBER = t1.PRODUCTNUMBER
		WHERE t1.PRODUCTNUMBER IS NULL
	)
	INSERT INTO dbo.PRS_Retail_Parts (BrandID, PRODUCTNUMBER, PartName, CLEANPRODUCTNUMBER)
	SELECT t1.BrandID, t0.PRODUCTNUMBER, t0.PRODUCTNAME, 
	RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(PRODUCTNUMBER, '-', ''), '\', ''), ' ', ''), '/', ''), '.', '')))
	FROM C_1 AS t0 INNER JOIN dbo.PRS_Retail_Brand AS t1
	ON t0.Retail_Xmfg = t1.RetailXmfg 
	AND t0.PRODUCTBRAND = t1.PRODUCTBRAND;



	UPDATE t0
	SET t0.CLEANPRODUCTBRAND = t1.CLEANPRODUCTBRAND,
	t0.CLEANPRODUCTNUMBER = t1.CLEANPRODUCTNUMBER
	FROM PRS_Import_Retail AS t0
	INNER JOIN V_Retail_Parts_List AS t1
	ON t0.RETAIL_XMFG = t1.RetailXmfg
	AND t0.PRODUCTBRAND = t1.PRODUCTBRAND
	AND t0.PRODUCTNUMBER = t1.PRODUCTNUMBER;



	WITH C AS
	(
		SELECT Retail_Xmfg, CLEANPRODUCTBRAND, CLEANPRODUCTNUMBER,
		CONVERT(DATE, MAX(DATE_CREATED)) AS LastShop
		FROM PRS_Import_Retail
		WHERE PRICE > 0 GROUP BY Retail_Xmfg, CLEANPRODUCTBRAND, CLEANPRODUCTNUMBER
	),
	C_1 AS
	(
		SELECT t0.RETAIL_XMFG, t0.CLEANPRODUCTBRAND, t0.CLEANPRODUCTNUMBER, PRICE, COREPRICE, ZIPCODE, LastShop
		FROM PRS_Import_Retail AS t0
		INNER JOIN C AS t1
		ON t0.RETAIL_XMFG = t1.RETAIL_XMFG
		AND t0.CLEANPRODUCTNUMBER = t1.CLEANPRODUCTNUMBER
		AND t0.CLEANPRODUCTBRAND = t1.CLEANPRODUCTBRAND
		AND CONVERT(DATE, DATE_CREATED) = t1.LastShop
		WHERE t0.PRICE > 0
	),
	C_2 AS
	(
		SELECT RETAIL_XMFG, CLEANPRODUCTBRAND, CLEANPRODUCTNUMBER,
		MIN(PRICE) AS MinPrice, MAX(PRICE) AS MaxPrice, AVG(PRICE) 
		AS AvgPrice, AVG(COREPRICE) AS AvgCore, COUNT(DISTINCT ZIPCODE) AS ShopCnt, LastShop
		FROM C_1 GROUP BY RETAIL_XMFG, CLEANPRODUCTBRAND, CLEANPRODUCTNUMBER, LastShop
	)
	--INSERT INTO Import_Staging_LastShop(Retail_Xmfg, PartBrandClean, PartNumClean, PartName, 
	--MinPrice, MaxPrice, AvgPrice, AvgCore, ShopCnt, LastShop, AltXmfg)
	SELECT t1.RetailXmfg, t1.CLEANPRODUCTBRAND, t1.CLEANPRODUCTNUMBER, t1.PartName, t0.MinPrice, t0.MaxPrice,
	t0.AvgPrice, t0.AvgCore, t0.ShopCnt, t0.LastShop, t1.AltXmfg 
	INTO Import_Staging_LastShop
	FROM C_2 AS t0
	INNER JOIN dbo.V_Retail_Parts_List AS t1
	ON t0.CLEANPRODUCTBRAND = t1.CLEANPRODUCTBRAND
	AND t0.CLEANPRODUCTNUMBER = t1.CLEANPRODUCTNUMBER
	AND t0.RETAIL_XMFG = t1.RetailXmfg;



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
	SELECT t1.FS_Part AS BasePart, t2.ACI, t2.PRO AS ProSource, t2.Hayden, t0.RetailXmfg, t0.ALTXMFG, 
	t0.CLEANPRODUCTNUMBER AS MfgPart, t0.CLEANPRODUCTBRAND AS MfgBrand, t0.PartName AS MfgDescription, 
	t0.MinPrice, t0.MaxPrice, t0.AvgPrice, t0.AvgCore, t0.ShopCnt, t0.LastShop, t1.D_I
	INTO DM_SMP_Pricing.dbo.PRS_Retail_Prices_v3
	FROM dbo.import_Staging_LastShop AS t0 
	INNER JOIN DW_Marketing.dbo.DW_XRF_Xref AS t1
	ON t0.CLEANPRODUCTNUMBER = t1.CompClean AND t0.AltXmfg = t1.XMfg
	INNER JOIN C_2 AS t2 
	ON t1.FS_Part = t2.BasePart
	GROUP BY t1.FS_Part, t2.ACI, t2.PRO, t2.Hayden, t0.RETAILXMFG, t0.ALTXMFG, 
	t0.CLEANPRODUCTNUMBER, t0.CLEANPRODUCTBRAND, t0.PartName, 
	t0.MinPrice, t0.MaxPrice, t0.AvgPrice, t0.AvgCore, t0.ShopCnt, t0.LastShop, t1.D_I;

END
