//
//  LunarDate.m
//  Helium
//
//  Created by Fuuko on 2024/3/25.
//

#import "LunarDate.h"

#define ChineseMonths        @[@"正月", @"二月", @"三月", @"四月", @"五月", @"六月", @"七月", @"八月", @"九月", @"十月", @"冬月", @"腊月"]
#define ChineseMonthsNumbers @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12"]

#define ChineseDays          @[@"初一", @"初二", @"初三", @"初四", @"初五", @"初六", @"初七", @"初八", @"初九", @"初十", @"十一", @"十二", @"十三", @"十四", @"十五", @"十六", @"十七", @"十八", @"十九", @"二十", @"廿一", @"廿二", @"廿三", @"廿四", @"廿五", @"廿六", @"廿七", @"廿八", @"廿九", @"三十"]
#define ChineseDaysNumbers   @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12", @"13", @"14", @"15", @"16", @"17", @"18", @"19", @"20", @"21", @"22", @"23", @"24", @"25", @"26", @"27", @"28", @"29", @"30"]

#define ChineseYears         @[@"甲子", @"乙丑", @"丙寅", @"丁卯", @"戊辰", @"己巳", @"庚午", @"辛未", @"壬申", @"癸酉", @"甲戌", @"乙亥", @"丙子", @"丁丑", @"戊寅", @"己卯", @"庚辰", @"辛巳", @"壬午", @"癸未", @"甲申", @"乙酉", @"丙戌", @"丁亥", @"戊子", @"己丑", @"庚寅", @"辛卯", @"壬辰", @"癸巳", @"甲午", @"乙未", @"丙申", @"丁酉", @"戊戌", @"己亥", @"庚子", @"辛丑", @"壬寅", @"癸卯", @"甲辰", @"乙巳", @"丙午", @"丁未", @"戊申", @"己酉", @"庚戌", @"辛亥", @"壬子", @"癸丑", @"甲寅", @"乙卯", @"丙辰", @"丁巳", @"戊午", @"己未", @"庚申", @"辛酉", @"壬戌", @"癸亥"]

@implementation LunarDate

+ (NSCalendar *)chineseCalendar {
    static NSCalendar *chineseCalendar_sharedCalendar = nil;

    if (!chineseCalendar_sharedCalendar) {
        chineseCalendar_sharedCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierChinese];
    }

    return chineseCalendar_sharedCalendar;
}

/**
   Get the lunar year, month, and day.

   @param date Input date
   @return Return the lunar year, lunar month, and lunar day
 */
+ (NSString *)getChineseCalendarWithDate:(NSDate *)date format:(NSString *)format {
    NSCalendar *chineseCalendar = [[self class] chineseCalendar];
    unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay;
    NSDateComponents *localeComp = [chineseCalendar components:unitFlags fromDate:date];

    NSString *y_str = [NSString stringWithFormat:@"%@年", [ChineseYears objectAtIndex:localeComp.year - 1]];
    NSString *m_str = [ChineseMonths objectAtIndex:localeComp.month - 1];
    NSString *mn_str = [ChineseMonthsNumbers objectAtIndex:localeComp.month - 1];
    NSString *d_str = [ChineseDays objectAtIndex:localeComp.day - 1];
    NSString *dn_str = [ChineseDaysNumbers objectAtIndex:localeComp.day - 1];

    format = [format stringByReplacingOccurrencesOfString:@"CNYY" withString:y_str];
    format = [format stringByReplacingOccurrencesOfString:@"CNMM" withString:m_str];
    format = [format stringByReplacingOccurrencesOfString:@"CNmm" withString:mn_str];
    format = [format stringByReplacingOccurrencesOfString:@"CNDD" withString:d_str];
    format = [format stringByReplacingOccurrencesOfString:@"CNdd" withString:dn_str];
    return format;
}

@end
