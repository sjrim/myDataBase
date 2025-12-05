-- 4. LL_CHANNELS
CREATE TABLE LL_CHANNELS (
    CHANNEL_ID    INT           NOT NULL,
    CHANNELS_DESC VARCHAR(100)  NOT NULL,
    CHANNEL_CLASS VARCHAR(20)   NOT NULL,
    CHANNEL_TOTAL VARCHAR(30)   NULL, -- constant label, not used in analysis
    CONSTRAINT PK_LL_CHANNELS PRIMARY KEY (CHANNEL_ID),
    CONSTRAINT CK_CHANNEL_CLASS
        CHECK (CHANNEL_CLASS IN ('Direct','Indirect','Other'))
);


USE [2025DBFall_Group_5_DB]
GO

SELECT DISTINCT CHANNEL_CLASS
FROM LIY26.dbo.LI_CHANNELS
ORDER BY CHANNEL_CLASS;

ALTER TABLE dbo.LL_CHANNELS
DROP CONSTRAINT CK_CHANNEL_CLASS;   -- the name from the error
GO

INSERT INTO dbo.LL_CHANNELS (
    CHANNEL_ID,
    CHANNELS_DESC,
    CHANNEL_CLASS,
    CHANNEL_TOTAL
)
SELECT
    CHANNEL_ID,
    CHANNEL_DESC,
    CHANNEL_CLASS,
    CHANNEL_TOTAL
FROM LIY26.dbo.LI_CHANNELS;
GO



--CHANNEL_CLASS (LL_CHANNELS – CK_CHANNEL_CLASS)

--Initial design: CK_CHANNEL_CLASS allowed only a small set of classes (for example, {Direct, Indirect, Other}).

--Problem observed: the LI_CHANNELS.CHANNEL_CLASS field uses a slightly different set of labels, which led to a check-constraint violation during loading.

--Resolution: we removed CK_CHANNEL_CLASS and accepted the full set of channel classes from the source table.