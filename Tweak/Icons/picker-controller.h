#import <UIKit/UIKit.h>

@interface RFPickerController : UIViewController

+ (void)presentWithTitle:(NSString *)title
                selected:(NSString *)selected
                  anchor:(CGRect (^)(void))anchor
              completion:(void (^)(NSString *name))completion;

@end
