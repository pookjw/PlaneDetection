//
//  CollectionViewController.mm
//  PlaneDetection
//
//  Created by Jinwoo Kim on 5/27/24.
//

#import "CollectionViewController.h"
#import <ARKit/ARKit.h>
#import "PlaneDetection-Swift.h"
#import "MTARViewController.h"

__attribute__((objc_direct_members))
@interface CollectionViewController ()
@property (retain, nonatomic, readonly) UICollectionViewCellRegistration *cellRegistration;
@property (nonatomic, readonly) NSArray<Class> *viewControllerClasses;
@end

@implementation CollectionViewController
@synthesize cellRegistration = _cellRegistration;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    UICollectionLayoutListConfiguration *listConfiguration = [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearanceInsetGrouped];
    UICollectionViewCompositionalLayout *collectionViewLayout = [UICollectionViewCompositionalLayout layoutWithListConfiguration:listConfiguration];
    [listConfiguration release];
    
    self = [super initWithCollectionViewLayout:collectionViewLayout];
    return self;
}

- (void)dealloc {
    [_cellRegistration release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self cellRegistration];
    
    UINavigationItem *navigationItem = self.navigationItem;
    navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    navigationItem.title = @"Plane";
}

- (UICollectionViewCellRegistration *)cellRegistration {
    if (auto cellRegistration = _cellRegistration) return cellRegistration;
    
    auto viewControllerClasses = self.viewControllerClasses;
    
    UICollectionViewCellRegistration *cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:UICollectionViewListCell.class configurationHandler:^(__kindof UICollectionViewListCell * _Nonnull cell, NSIndexPath * _Nonnull indexPath, id  _Nonnull item) {
        UIListContentConfiguration *contentConfiguration = [cell defaultContentConfiguration];
        contentConfiguration.text = NSStringFromClass(viewControllerClasses[indexPath.item]);
        cell.contentConfiguration = contentConfiguration;
        
        UICellAccessoryDisclosureIndicator *disclosureIndicator = [UICellAccessoryDisclosureIndicator new];
        cell.accessories = @[disclosureIndicator];
        [disclosureIndicator release];
    }];
    
    _cellRegistration = [cellRegistration retain];
    return cellRegistration;
}

- (NSArray<Class> *)viewControllerClasses {
    return @[
        ARViewController.class,
        MTARViewController.class
    ];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.viewControllerClasses.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [collectionView dequeueConfiguredReusableCellWithRegistration:self.cellRegistration forIndexPath:indexPath item:[NSNull null]];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    Class isa = self.viewControllerClasses[indexPath.item];
    
    UIViewController *viewController = (UIViewController *)[isa new];
    [self.navigationController pushViewController:viewController animated:YES];
    [viewController release];
}

@end
