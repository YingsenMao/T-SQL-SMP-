USE [DM_SMP_Pricing]
GO
/****** Object:  StoredProcedure [db_datawriter].[Update_JDE_Comp_Retail_Pivot]    Script Date: 9/4/2017 5:54:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [db_datawriter].[Update_JDE_Comp_Retail_Pivot]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DROP TABLE IF EXISTS [DM_SMP_Pricing].[db_datawriter].CompPrice_Pivot;
	DROP TABLE IF EXISTS [DM_SMP_Pricing].[db_datawriter].RetailPrice_Pivot;
	--DROP TABLE IF EXISTS [DM_SMP_Pricing].[db_datawriter].PRS_JDE_Comp_Retail_Pivot;

	WITH C AS
	(
		SELECT t1.FS_Part, t0.XMfg AS CompXMfg, Avg(t0.PriceWD) AS WDPrice FROM Comp_PriceSheet AS t0 
		INNER JOIN DW_Marketing.dbo.DW_XRF_Xref AS t1
		ON t0.XMfg = t1.XMfg AND t0.XMfgPart = t1.CompPart
		WHERE T1.FS_Part NOT LIKE 'N%' AND t0.PriceWD <> 0 AND t0.XMfg IN ('DOR', 'VDO', 'GAT','GIL','GPD','MEI','SNT','SPI','TAP','UAC','USM')
		GROUP BY t1.FS_Part, t0.XMfg
	)
	SELECT FS_Part, DOR, VDO, GAT,GIL,GPD,MEI,SNT,SPI,TAP,UAC,USM
	INTO [DM_SMP_Pricing].[db_datawriter].CompPrice_Pivot
	FROM C
	PIVOT (AVG(WDPrice) FOR CompXMfg IN (DOR, VDO, GAT, GIL, GPD, MEI, SNT, SPI, TAP, UAC, USM))
	AS PVT order by FS_Part;

	WITH C AS
	(
		SELECT BasePart, RETAIL_XMFG, AvgPrice FROM PRS_Retail_Prices WHERE BasePart NOT LIKE 'N%'
	)
	SELECT BasePart, AZR, ADV, ORY, NAP, PBR, PAG, ROC, SMR, AMZ
	INTO [DM_SMP_Pricing].[db_datawriter].RetailPrice_Pivot
	FROM C 
	PIVOT (AVG(AvgPrice) FOR RETAIL_XMFG IN (AZR, ADV, ORY, NAP, PBR, PAG, ROC, SMR, AMZ))
	AS PVT order by BasePart;


	--SELECT t0.*, t1.DOR, t1.VDO, t1.GAT, t1.GIL, t1.GPD, t1.MEI, t1.SNT, t1.SPI, t1.TAP, t1.UAC, t1.USM,
	--t2.AZR, t2.ADV, t2.ORY, t2.NAP, t2.PBR, t2.PAG, t2.ROC, t2.SMR, t2.AMZ
	--INTO [DM_SMP_Pricing].[db_datawriter].PRS_JDE_Comp_Retail_Pivot
	--FROM [DM_SMP_Pricing].[db_datawriter].Current_JDE_Price_Pivot AS t0
	--LEFT JOIN [DM_SMP_Pricing].[db_datawriter].CompPrice_Pivot AS t1
	--ON t0.PartNumber = t1.FS_Part
	--LEFT JOIN [DM_SMP_Pricing].[db_datawriter].RetailPrice_Pivot AS t2
	--ON t0.PartNumber = t2.BasePart;


END
