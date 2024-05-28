//
//  MTARViewController.mm
//  PlaneDetection
//
//  Created by Jinwoo Kim on 5/28/24.
//

#import "MTARViewController.h"
#import "MTARView.h"

__attribute__((objc_direct_members))
@interface MTARViewController ()
@property (readonly, nonatomic) MTARView *mtARView;
@end

@implementation MTARViewController

- (void)loadView {
    MTARView *view = [MTARView new];
    self.view = view;
    [view release];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.mtARView start];
}

- (MTARView *)mtARView {
    return (MTARView *)self.view;
}

@end
