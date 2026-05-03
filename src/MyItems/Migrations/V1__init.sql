-- V1: 初始版本 - 创建基础表结构与预设分类

CREATE TABLE IF NOT EXISTS "VersionLog" (
    "Id" text NOT NULL,
    "Version" integer NOT NULL,
    "Description" text NOT NULL,
    "AppliedAt" text NOT NULL,
    CONSTRAINT "PK_VersionLog" PRIMARY KEY ("Id")
);

CREATE TABLE IF NOT EXISTS "Categories" (
    "Id" text NOT NULL,
    "Name" text NOT NULL,
    "Icon" text,
    "SortOrder" integer NOT NULL DEFAULT 0,
    "IsPreset" integer NOT NULL DEFAULT 0,
    "IsActive" integer NOT NULL DEFAULT 1,
    CONSTRAINT "PK_Categories" PRIMARY KEY ("Id")
);

CREATE TABLE IF NOT EXISTS "Items" (
    "Id" text NOT NULL,
    "CategoryId" text NOT NULL,
    "Barcode" text,
    "Brand" text,
    "Icon" text,
    "DefaultLocation" text,
    "IsArchived" integer NOT NULL DEFAULT 0,
    "PurchaseDate" text,
    "PurchasePrice" text,
    "ExpiryDate" text,
    "Quantity" integer NOT NULL DEFAULT 1,
    "TrackDailyCost" integer NOT NULL DEFAULT 0,
    "Notes" text,
    "ImagePath" text,
    "CreatedAt" text NOT NULL,
    "UpdatedAt" text NOT NULL,
    CONSTRAINT "PK_Items" PRIMARY KEY ("Id")
);

CREATE INDEX IF NOT EXISTS "IX_Items_CategoryId" ON "Items" ("CategoryId");

CREATE INDEX IF NOT EXISTS "IX_Items_IsArchived" ON "Items" ("IsArchived");

CREATE INDEX IF NOT EXISTS "IX_Items_ExpiryDate" ON "Items" ("ExpiryDate");

-- 预设分类
INSERT OR IGNORE INTO "Categories" ("Id", "Name", "Icon", "SortOrder", "IsPreset", "IsActive") VALUES ('10000000-0000-0000-0000-000000000001', '食品', '🍔', 1, 1, 1);
INSERT OR IGNORE INTO "Categories" ("Id", "Name", "Icon", "SortOrder", "IsPreset", "IsActive") VALUES ('10000000-0000-0000-0000-000000000002', '化妆品/护肤品', '💄', 2, 1, 1);
INSERT OR IGNORE INTO "Categories" ("Id", "Name", "Icon", "SortOrder", "IsPreset", "IsActive") VALUES ('10000000-0000-0000-0000-000000000003', '药品/保健品', '💊', 3, 1, 1);
INSERT OR IGNORE INTO "Categories" ("Id", "Name", "Icon", "SortOrder", "IsPreset", "IsActive") VALUES ('10000000-0000-0000-0000-000000000004', '日用品', '🧴', 4, 1, 1);
INSERT OR IGNORE INTO "Categories" ("Id", "Name", "Icon", "SortOrder", "IsPreset", "IsActive") VALUES ('10000000-0000-0000-0000-000000000005', '电子产品', '💻', 5, 1, 1);
INSERT OR IGNORE INTO "Categories" ("Id", "Name", "Icon", "SortOrder", "IsPreset", "IsActive") VALUES ('10000000-0000-0000-0000-000000000006', '其他', '📦', 6, 1, 1);
