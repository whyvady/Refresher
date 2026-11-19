#import <UIKit/UIKit.h>

@interface RFExplorerController : UIViewController

- (instancetype)initWithHandler:(void (^)(UIImage *image))handler;

@end
