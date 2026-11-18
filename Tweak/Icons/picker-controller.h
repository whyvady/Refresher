#import <UIKit/UIKit.h>

@interface RFPickerController : UIViewController

- (instancetype)initWithTitle:(NSString *)title
                     selected:(NSString *)selected
                   completion:(void (^)(NSString *name))completion;

@end
