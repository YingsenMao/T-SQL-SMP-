USE [DM_SMP_Pricing]
GO
/****** Object:  StoredProcedure [dbo].[UpdateCompetitorPriceSheet]    Script Date: 9/4/2017 5:50:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Daniel Mao>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[UpdateCompetitorPriceSheet]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	DECLARE @newDate datetime, @existingDate datetime
	SELECT @newDate = MAX(t0.Date_Created) FROM [DM_SMP_Pricing].[dbo].[Nuway_Import] AS t0 INNER JOIN [DM_SMP_Pricing].[dbo].[MFNline_Name] AS t1
	ON t0.MFRLINE = t1.mfrline AND t1.Xmfg IS NOT NULL;
	SELECT @existingDate = MAX(PS_Date_Created) FROM [DM_SMP_Pricing].[dbo].[Comp_PriceSheet];
	--SELECT @newDate
	--SELECT @existingDate
	IF @newDate > @existingDate
	BEGIN
		WITH C AS
		(
			SELECT t0.MFRLINE, t0.MFRNAME, CAST(CONVERT(varchar(8), t0.Date_Created, 112) AS INT) AS new_psID, CONVERT(date, t0.PSDATE, 101) as PSDATE, t0.PARTNO,
			t0.DESCRIP, t0.POPCODE, t0.UOM1, t0.WD1, t0.JOBBER1, t1.XMfg, t0.Date_Created AS CreatDate
			FROM Nuway_Import AS t0 INNER JOIN [DM_SMP_Pricing].[dbo].[MFNline_Name] AS t1
			ON t0.MFRLINE = t1.mfrline AND t1.Xmfg IS NOT NULL
			WHERE t0.Date_Created > @existingDate
		)
		SELECT t0.*, t1.XMfg AS XMfg_2, t1.XMfgPartClean AS Flag, t1.XMfgUOM, t1.XMfgPOP, t1.PriceWD, t1.AcquisitionType, 
		t1.PriceJobber, t1.PriceList, t1.PriceRetail, t1.psID as old_psID, t1.CoreCharge, t1.DateEffective, t1.XMfgPartType, t1.XMfgPartCategory, t1.XREFGroup
		INTO #StagingTB FROM C AS t0
		LEFT JOIN [DM_SMP_Pricing].[dbo].[Comp_PriceSheet] AS t1
		ON t0.Xmfg = t1.XMfg AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t0.PARTNO, ' ', ''), '-', ''), '\', ''), '/', ''), '.', '') =t1.XMfgPartClean;


		INSERT INTO [DM_SMP_Pricing].[dbo].[Comp_PriceSheet] (psID,XREFGroup,XMfgPartCategory,XMfgPartType
			  ,XMfg,XMfgSKU,XMfgPart,XMfgPartClean,XMfgPartSuper,XMfgPartSuperClean,XMfgPOP
			  ,XMfgUOM,DateEffective,CoreCharge,AcquisitionType,PriceAcquistion,PriceJobber,PriceWD
			  ,PriceList,PriceRetail,PriceProgramStart, PS_Date_Created)
			  SELECT new_psID,NULL AS XREFGroup,NULL AS XMfgPartCategory, DESCRIP
			  ,XMfg, NULL AS XMfgSKU, PARTNO AS XMfgPart, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(PARTNO, ' ', ''), '-', ''), '\', ''), '/', ''), '.', '') AS XMfgPartClean,
			  NULL AS XMfgPartSuper, NULL AS XMfgPartSuperClean, POPCODE, UOM1, PSDATE, NULL AS CoreCharge, 
			  'WD Gross' AS AcquisitionType, WD1 as PriceAcquistion, JOBBER1, WD1, NULL AS PriceList, NULL AS PriceRetail, NULL AS PriceProgramStart, CreatDate FROM #StagingTB WHERE Flag IS NULL;

		UPDATE t0
			SET t0.[psID] = t1.new_psID
			  ,t0.[XMfgPartType] = t1.DESCRIP
			  ,t0.[XMfgPOP] = t1.POPCODE
			  ,t0.[XMfgUOM] = t1.UOM1
			  ,t0.[DateEffective] = t1.PSDATE
			  ,t0.[PriceAcquistion] = t1.WD1
			  ,t0.[PriceJobber] = t1.JOBBER1
			  ,t0.[PriceWD] = t1.WD1
			  ,t0.PS_Date_Created = t1.CreatDate
			  FROM [DM_SMP_Pricing].[dbo].[Comp_PriceSheet] AS t0
			  INNER JOIN #StagingTB AS t1
			  ON t0.XMfgPartClean = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t1.PARTNO, ' ', ''), '-', ''), '\', ''), '/', ''), '.', '') And t0.XMfg = t1.XMfg
			  WHERE t1.Flag IS NOT NULL;
	END
	ELSE
		PRINT 'No New Items'
END
