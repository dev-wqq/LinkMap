//
//  DWSymbolViewModel+ExportExecl.m
//  LinkMap
//
//  Created by 王启启 on 2018/8/2.
//  Copyright © 2018年 ND. All rights reserved.
//

#import "DWSymbolViewModel+ExportExecl.h"
#import <xlsxwriter/xlsxwriter.h>

static lxw_format *_knameFormat;// 各表格标题栏的格式

static NSString * const kCurrentVersion = @"v7.1.4";
static NSString * const kHistoryVersion = @"v7.1.2";

@implementation DWSymbolViewModel (ExportExecl)

- (void)exportCompareVersionExecl:(NSString *)fileName {
    if (self.resultArray.count == 0) {
        return;
    }
    lxw_workbook *workbook = workbook_new(fileName.UTF8String);
    lxw_worksheet *worksheet = workbook_add_worksheet(workbook, NULL);
    NSString *moduleName = self.frameworkAnalyze ? @"模块名称" : @"文件名称";
    NSArray *titles = @[@"序号", kCurrentVersion,@"__TEXT",@"__DATA", kHistoryVersion,@"__TEXT",@"__DATA",@"版本差异",@"__TEXT",@"__DATA", moduleName];
    [self addCompareTitleForWorksheet:worksheet titles:titles];
    [self addEportDataAddSubFile:worksheet dataSource:self.resultArray];
    workbook_close(workbook);
}

- (void)exportSingleExecl:(NSString *)fileName {
    if (self.resultArray.count == 0) {
        return;
    }
    lxw_workbook *workbook = workbook_new(fileName.UTF8String);
    lxw_worksheet *worksheet = workbook_add_worksheet(workbook, NULL);
    NSString *moduleName = self.frameworkAnalyze ? @"模块名称" : @"文件名称";
    NSArray *titles = @[@"序号", kCurrentVersion,@"__TEXT",@"__DATA", moduleName];
    [self addCompareTitleForWorksheet:worksheet titles:titles];
    [self addCompareContentForWorksheet:worksheet dataSource:self.resultArray];
    workbook_close(workbook);
}

- (NSArray *)makeModuleWhitelistData:(NSArray *)dataSource {
    if (!self.whitelistURL || self.whitelistSet.count == 0) {
        return nil;
    }
    NSMutableArray *mArr = [NSMutableArray array];
    for (DWFrameWorkModel *model in dataSource) {
        if ([self.whitelistSet containsObject:model.frameworkName]) {
            [mArr addObject:model];
        }
    }
    return mArr;
}

- (void)exportReportDataWithFileName:(NSString *)fileName {
    lxw_workbook *workbook = workbook_new(fileName.UTF8String);
    // 所有模块，通过模块大小降序排序
    NSArray *dataSource = self.frameworkSymbolMap.allValues;
    NSArray *frameworks = [self sortedWithArr:dataSource];
    [self makeReportSheetWithWorkbook:workbook
                            sheetName:[self c_charFromString:@"by_total_size"]
                           dataSource:frameworks];
    
    frameworks = [self sortedWithArr:dataSource style:DWSortedTextSize];
    [self makeReportSheetWithWorkbook:workbook
                            sheetName:[self c_charFromString:@"by_text_size"]
                           dataSource:frameworks];
    
    // 所有模块，通过版本对比大小降序排序
    frameworks = [self sortedWithArr:self.frameworkSymbolMap.allValues style:DWSortedTextDiffSize];
    [self makeReportSheetWithWorkbook:workbook
                            sheetName:[self c_charFromString:@"by_text_diff_size"]
                           dataSource:frameworks];
    
    
    NSArray *whitelist = [self makeModuleWhitelistData:self.frameworkSymbolMap.allValues];
    
    if (whitelist.count > 0) {
        // 所有名单内，通过版本对比大小降序排序
        NSArray *sortedDifffArr = [self sortedWithArr:whitelist style:DWSortedTextDiffSize];
        [self makeReportSheetWithWorkbook:workbook
                                sheetName:[self c_charFromString:@"sh_by_text_diff_size"]
                               dataSource:sortedDifffArr];
    }
    workbook_close(workbook);
}

- (void)makeReportSheetWithWorkbook:(lxw_workbook *)workbook
                    sheetName:(const char*)sheetName
                   dataSource:(NSArray *)dataSource {
    lxw_worksheet *worksheet = workbook_add_worksheet(workbook, sheetName);
    [self addCompareTitleForWorksheet:worksheet titles:[self dw_compareTitles]];
    [self addCompareContentForWorksheet:worksheet dataSource:dataSource];
}

- (void)makeGroupAddSheetWithWorkbook:(lxw_workbook *)workbook
                          sheetName:(const char*)sheetName
                         dataSource:(NSArray *)dataSource  {
    lxw_worksheet *worksheet = workbook_add_worksheet(workbook, sheetName);
    [self addCompareTitleForWorksheet:worksheet titles:[self dw_compareTitles]];
    [self addEportCustomDataAddSubFile:worksheet dataSource:dataSource];
}

/// add sheet titles
- (void)addCompareTitleForWorksheet:(lxw_worksheet *)worksheet
                             titles:(NSArray *)titles {
    for (int i = 0; i < titles.count; i++) {
        NSString *title = titles[i];
        char const *c_title = [title cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, 0, i, c_title, _knameFormat);
    }
}

#pragma mark - Compare Version Methods

/// 添加内容数据
- (void)addEportDataAddSubFile:(lxw_worksheet *)worksheet
                    dataSource:(NSArray *)dataSource {
    NSUInteger totalSize = 0;
    NSUInteger hisTotalSize = 0;
    
    NSUInteger totalTextSize = 0;
    NSUInteger totalHisTextSize = 0;
    
    NSUInteger totalDataSize = 0;
    NSUInteger totalHisDataSize = 0;
    int totalNumber = 0;
    for (int index = 0; index < dataSource.count; index++) {
        DWBaseModel *model = dataSource[index];
        totalNumber = totalNumber + 1;
        [self addCompareRowForWorkSheet:worksheet model:model indexName:@(index+1).stringValue index:totalNumber];
        if ([model isKindOfClass:[DWFrameWorkModel class]] &&
            ((DWFrameWorkModel *)model).displayArr.count > 0) {
            DWFrameWorkModel *frameworkModel = (DWFrameWorkModel *)model;
            int indexSorted = 0;
            for (int j = 0; j < frameworkModel.displayArr.count; j++) {
                DWBaseModel *subModel = frameworkModel.displayArr[j];
                if (subModel.total.differentSize != 0) {
                    totalNumber++;
                    indexSorted++;
                    NSString *indexName = [NSString stringWithFormat:@"%d_%d",index+1,indexSorted];
                    [self addCompareRowForWorkSheet:worksheet model:subModel indexName:indexName index:totalNumber];
                }
            }
        }
        totalSize += model.total.size;
        hisTotalSize += model.total.historySize;
        
        totalTextSize += model.text.size;
        totalHisTextSize += model.text.historySize;
        
        totalDataSize += model.data.size;
        totalHisDataSize += model.data.historySize;
    }
    NSInteger lastIndex = totalNumber+1;
    [self addCompareTotalForWorkSheet:worksheet
                            totalSize:totalSize
                         hisTotalSize:hisTotalSize
                        totalTextSize:totalTextSize
                     totalHisTextSize:totalHisTextSize
                        totalDataSize:totalDataSize
                     totalHisDataSize:totalHisDataSize
                            lastIndex:(int)lastIndex];
}

/// 添加内容数据
- (void)addEportCustomDataAddSubFile:(lxw_worksheet *)worksheet
                          dataSource:(NSArray *)dataSource {
    NSUInteger totalSize = 0;
    NSUInteger hisTotalSize = 0;
    
    NSUInteger totalTextSize = 0;
    NSUInteger totalHisTextSize = 0;
    
    NSUInteger totalDataSize = 0;
    NSUInteger totalHisDataSize = 0;
    int totalNumber = 0;
    for (int index = 0; index < dataSource.count; index++) {
        DWBaseModel *model = dataSource[index];
        totalNumber = totalNumber + 1;
        [self addCompareRowForWorkSheet:worksheet model:model indexName:@(index+1).stringValue index:totalNumber];
        if ([model isKindOfClass:[DWFrameWorkModel class]]) {
            DWFrameWorkModel *frameworkModel = (DWFrameWorkModel *)model;
            NSArray *sortedArr = [self sortedWithArr:frameworkModel.subMap.allValues];
            int indexSorted = 0;
            for (int j = 0; j < sortedArr.count; j++) {
                DWBaseModel *subModel = sortedArr[j];
                if (subModel.total.differentSize != 0) {
                    totalNumber++;
                    indexSorted++;
                    NSString *indexName = [NSString stringWithFormat:@"%d_%d",index+1,indexSorted];
                    [self addCompareRowForWorkSheet:worksheet model:subModel indexName:indexName index:totalNumber];
                }
            }
        }
        totalSize += model.total.size;
        hisTotalSize += model.total.historySize;
        
        totalTextSize += model.text.size;
        totalHisTextSize += model.text.historySize;
        
        totalDataSize += model.data.size;
        totalHisDataSize += model.data.historySize;
    }
    NSInteger lastIndex = totalNumber+1;
    [self addCompareTotalForWorkSheet:worksheet
                            totalSize:totalSize
                         hisTotalSize:hisTotalSize
                        totalTextSize:totalTextSize
                     totalHisTextSize:totalHisTextSize
                        totalDataSize:totalDataSize
                     totalHisDataSize:totalHisDataSize
                            lastIndex:(int)lastIndex];
}

/// 添加内容数据
- (void)addCompareContentForWorksheet:(lxw_worksheet *)worksheet
                           dataSource:(NSArray *)dataSource  {
    NSUInteger totalSize = 0;
    NSUInteger hisTotalSize = 0;
    
    NSUInteger totalTextSize = 0;
    NSUInteger totalHisTextSize = 0;
    
    NSUInteger totalDataSize = 0;
    NSUInteger totalHisDataSize = 0;
    
    for (int index = 0; index < dataSource.count; index++) {
        DWBaseModel *model = dataSource[index];
        
        [self addCompareRowForWorkSheet:worksheet model:model index:index+1];
        totalSize += model.total.size;
        hisTotalSize += model.total.historySize;
        
        totalTextSize += model.text.size;
        totalHisTextSize += model.text.historySize;
        
        totalDataSize += model.data.size;
        totalHisDataSize += model.data.historySize;
    }
    NSInteger lastIndex = dataSource.count + 1;
    [self addCompareTotalForWorkSheet:worksheet
                            totalSize:totalSize
                         hisTotalSize:hisTotalSize
                        totalTextSize:totalTextSize
                     totalHisTextSize:totalHisTextSize
                        totalDataSize:totalDataSize
                     totalHisDataSize:totalHisDataSize
                            lastIndex:(int)lastIndex];
}

- (void)addCompareRowForWorkSheet:(lxw_worksheet *)worksheet
                            model:(DWBaseModel *)model
                            index:(int)index {
    return [self addCompareRowForWorkSheet:worksheet model:model indexName:@(index).stringValue index:index];
}

/// 添加每一条数据
- (void)addCompareRowForWorkSheet:(lxw_worksheet *)worksheet
                            model:(DWBaseModel *)model
                        indexName:(NSString *)indexName
                            index:(int)index {
    return [self addCompareRowForWorkSheet:worksheet model:model indexName:indexName index:index isCompare:NO];
}

/// 添加每一条数据
- (void)addCompareRowForWorkSheet:(lxw_worksheet *)worksheet
                            model:(DWBaseModel *)model
                        indexName:(NSString *)indexName
                            index:(int)index
                        isCompare:(BOOL)isCompare {
    int row = 0;
    char const *c_number = [indexName cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, index, row, c_number, _knameFormat);
    row++;
    
    char const *c_current = [model.total.sizeStr cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, index, row, c_current, _knameFormat);
    row++;
    
    char const *c_currentText = [model.text.sizeStr cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, index, row, c_currentText, _knameFormat);
    row++;
    
    char const *c_currentData = [model.data.sizeStr cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, index, row, c_currentData, _knameFormat);
    row++;
    
    if (self.historyViewModel) {
        char const *c_history = [model.total.historySizeStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, index, row, c_history, _knameFormat);
        row++;
        
        char const *c_historyText = [model.text.historySizeStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, index, row, c_historyText, _knameFormat);
        row++;
        
        char const *c_historyData = [model.data.historySizeStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, index, row, c_historyData, _knameFormat);
        row++;
        
        char const *c_diff = [model.total.differentSizeStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, index, row, c_diff, _knameFormat);
        row++;
        
        char const *c_diffText = [model.text.differentSizeStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, index, row, c_diffText, _knameFormat);
        row++;
        
        char const *c_diffData = [model.data.differentSizeStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, index, row, c_diffData, _knameFormat);
        row++;
    }
    
    char const *c_fileName = [model.showName cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, index, row, c_fileName, _knameFormat);
}

/// 添加总计cell
- (void)addCompareTotalForWorkSheet:(lxw_worksheet *)worksheet
                          totalSize:(NSUInteger)totalSize
                       hisTotalSize:(NSUInteger)hisTotalSize
                      totalTextSize:(NSUInteger)totalTextSize
                   totalHisTextSize:(NSUInteger)totalHisTextSize
                      totalDataSize:(NSUInteger)totalDataSize
                   totalHisDataSize:(NSUInteger)totalHisDataSize
                          lastIndex:(int)lastIndex {
    worksheet_write_string(worksheet, (int)lastIndex, 0, "", _knameFormat);
    lastIndex++;
    
    char const *c_total = [@"总计：" cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, (int)lastIndex, 0, c_total, _knameFormat);
    
    NSString *str = [DWCalculateHelper calculateSize:totalSize];
    char const *c_str = [[NSString stringWithFormat:@"%@",str] cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, (int)lastIndex, 1, c_str, _knameFormat);
    
    NSString *str_text = @(self.totalTextSize).stringValue;
    char const *c_str_text = [str_text cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, (int)lastIndex, 2, c_str_text, _knameFormat);
    
    NSString *str_data = @(self.totalDataSize).stringValue;
    char const *c_str_data = [str_data cStringUsingEncoding:NSUTF8StringEncoding];
    worksheet_write_string(worksheet, (int)lastIndex, 3, c_str_data, _knameFormat);
    
    if (self.historyViewModel) {
        NSString *hisStr = [DWCalculateHelper calculateSize:hisTotalSize];
        char const *c_hisStr = [[NSString stringWithFormat:@"%@",hisStr] cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, (int)lastIndex, 4, c_hisStr, _knameFormat);
        
        hisStr = @(self.historyViewModel.totalTextSize).stringValue;
        c_hisStr = [hisStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, (int)lastIndex, 5, c_hisStr, _knameFormat);
        
        hisStr = @(self.historyViewModel.totalDataSize).stringValue;
        c_hisStr = [hisStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, (int)lastIndex, 6, c_hisStr, _knameFormat);
        
        
        NSString *diffStr = [DWCalculateHelper calculateDiffSize:totalSize-hisTotalSize];
        char const *c_diffStr = [diffStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, (int)lastIndex, 7, c_diffStr, _knameFormat);
        
        diffStr = [DWCalculateHelper calculateDiffSize:totalTextSize-totalHisTextSize];
        c_diffStr = [diffStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, (int)lastIndex, 8, c_diffStr, _knameFormat);
        
        diffStr = [DWCalculateHelper calculateDiffSize:totalDataSize-totalHisDataSize];
        c_diffStr = [diffStr cStringUsingEncoding:NSUTF8StringEncoding];
        worksheet_write_string(worksheet, (int)lastIndex, 9, c_diffStr, _knameFormat);
    }
}

#pragma make - Helper Methods


- (NSArray *)dw_compareTitles {
    return @[@"序号", kCurrentVersion,@"__TEXT",@"__DATA", kHistoryVersion,@"__TEXT",@"__DATA",@"版本差异",@"__TEXT",@"__DATA", @"模块名称"];
}

- (NSArray *)dw_singleTitles {
    return @[@"序号", kCurrentVersion,@"__TEXT",@"__DATA", @"模块名称"];
}

- (const char *)c_charFromString:(NSString *)str {
    if (str) {
        return [str cStringUsingEncoding:NSUTF8StringEncoding];
    } else {
        return NULL;
    }
}

/// ss -> sorted size  sd -> sorted different size
- (const char *)c_allSSSheet {
    return [self c_charFromString:@"all_sorted_size"];
}

- (const char *)c_allSDSSheet {
    return [self c_charFromString:@"all_sorted_diff_size"];
}

- (const char *)c_whitelistSSSheet {
    return [self c_charFromString:@"sh_group_sorted_size"];
}

- (const char *)c_whitelistSSDSheet {
    return [self c_charFromString:@"sh_group_sorted_diff_size"];
}

@end
