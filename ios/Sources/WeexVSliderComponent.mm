//
//  WeexVSliderComponent.m
//  weex-plugin-v-slider
//
//  Created by jqoo on 2019/11/26.
//

#import "WeexVSliderComponent.h"

#import "WXIndicatorComponent.h"
#import "WXComponent_internal.h"
#import "NSTimer+Weex.h"
#import "WXSDKManager.h"
#import "WXUtility.h"
#import "WXComponent+Layout.h"
#import "WXComponent+Events.h"

#import <WeexPluginLoader/WeexPluginLoader.h>

@interface WeexVRecycleSliderScrollView: UIScrollView
@end

typedef NS_ENUM(NSInteger, Direction) {
    DirectionNone = 1 << 0,
    DirectionUp = 1 << 1,
    DirectionDown = 1 << 2
};

@class WeexVRecycleSliderView;
@class WXIndicatorView;

@protocol WeexVRecycleSliderViewDelegate <UIScrollViewDelegate>

- (void)recycleSliderView:(WeexVRecycleSliderView *)recycleSliderView didScroll:(UIScrollView *)scrollView;
- (void)recycleSliderView:(WeexVRecycleSliderView *)recycleSliderView didScrollToItemAtIndex:(NSInteger)index;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (BOOL)requestGestureShouldStopPropagation:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;

@end


@interface WeexVRecycleSliderView : UIView <UIScrollViewDelegate>

@property (nonatomic, strong) WXIndicatorView *indicator;
@property (nonatomic, weak) id<WeexVRecycleSliderViewDelegate> delegate;
@property (nonatomic, strong) WeexVRecycleSliderScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *itemViews;
@property (nonatomic, assign) Direction direction;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) NSInteger nextIndex;
@property (nonatomic, assign) CGRect currentItemFrame;
@property (nonatomic, assign) CGRect nextItemFrame;
@property (nonatomic, assign) BOOL infinite;
@property (nonatomic, assign) BOOL forbidSlideAnimation;

- (void)insertItemView:(UIView *)view atIndex:(NSInteger)index;
- (void)removeItemView:(UIView *)view;

@end

@implementation WeexVRecycleSliderView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _currentIndex = 0;
        _itemViews = [[NSMutableArray alloc] init];
        _scrollView = [[WeexVRecycleSliderScrollView alloc] init];
        if (@available(iOS 11.0, *)) {
            _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        _scrollView.backgroundColor = [UIColor clearColor];
        _scrollView.delegate = self;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.scrollsToTop = NO;
        [self addSubview:_scrollView];
    }
    return self;
}

- (void)dealloc
{
    if (_scrollView) {
        _scrollView.delegate = nil;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self resetAllViewsFrame];
}

- (void)accessibilityDecrement
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.wx_component performSelector:NSSelectorFromString(@"resumeAutoPlay:") withObject:@(false)];
#pragma clang diagnostic pop
    
    [self nextPage];
}

- (void)accessibilityIncrement
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.wx_component performSelector:NSSelectorFromString(@"resumeAutoPlay:") withObject:@(false)];
#pragma clang diagnostic pop
    
    [self lastPage];
}

- (void)accessibilityElementDidLoseFocus
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.wx_component performSelector:NSSelectorFromString(@"resumeAutoPlay:") withObject:@(true)];
#pragma clang diagnostic pop
}

#pragma mark Private Methods
- (CGFloat)height {
    return self.frame.size.height;
}

- (CGFloat)width {
    return self.frame.size.width;
}

- (UIView *)getItemAtIndex:(NSInteger)index
{
    if (self.itemViews.count > index) {
        return [self.itemViews objectAtIndex:index];
    }else{
        return nil;
    }
}

- (void)setCurrentIndex:(NSInteger)currentIndex
{
    if (currentIndex >= _itemViews.count || currentIndex < 0) {
        currentIndex = 0;
    }
    NSInteger oldIndex = _currentIndex;
    _currentIndex = currentIndex;
    if (_infinite) {
        if (_direction == DirectionDown) {
            self.nextItemFrame = CGRectMake(0, 0, self.width, self.height);
            self.nextIndex = self.currentIndex - 1;
            if (self.nextIndex < 0)
            {
                self.nextIndex = _itemViews.count - 1;
            }
        }else if (_direction == DirectionUp) {
            self.nextItemFrame = CGRectMake(0, self.height * 2, self.width, self.height);
            self.nextIndex = _itemViews.count?(self.currentIndex + 1) % _itemViews.count:0;
        }else {
            self.nextIndex = _itemViews.count?(self.currentIndex + 1) % _itemViews.count:0;
        }
        [self resetAllViewsFrame];
    } else {
        [_scrollView setContentOffset:CGPointMake(0, _currentIndex * self.height) animated:!_forbidSlideAnimation];
    }
    [self resetIndicatorPoint];
    if (self.delegate && [self.delegate respondsToSelector:@selector(recycleSliderView:didScrollToItemAtIndex:)]) {
        if (oldIndex != _currentIndex) {
            [self.delegate recycleSliderView:self didScrollToItemAtIndex:_currentIndex];
        }
    }
}

- (void)resetIndicatorPoint
{
    [self.indicator setPointCount:self.itemViews.count];
    [self.indicator setCurrentPoint:_currentIndex];
}

#pragma mark  Scroll & Frames
- (void)setDirection:(Direction)direction {
    if (_direction == direction) return;
    _direction = direction;
    if (_direction == DirectionNone) return;
    if (_direction == DirectionDown) {
        self.nextItemFrame = CGRectMake(0, 0, self.width, self.height);
        self.nextIndex = self.currentIndex - 1;
        if (self.nextIndex < 0)
        {
            self.nextIndex = _itemViews.count - 1;
        }
        UIView *view = [self getItemAtIndex:_nextIndex];
        if (view) {
            view.frame = _nextItemFrame;
        }
    }else if (_direction == DirectionUp){
        self.nextItemFrame = CGRectMake(0, self.height * 2, self.width, self.height);
        self.nextIndex = _itemViews.count?(self.currentIndex + 1) % _itemViews.count:0;
        UIView *view = [self getItemAtIndex:_nextIndex];
        if (view) {
            view.frame = _nextItemFrame;
        }
    }
}

- (void)resetAllViewsFrame
{
    if (_infinite && _itemViews.count > 1) {
        self.scrollView.frame = CGRectMake(0, 0, self.width, self.height);
        self.scrollView.contentOffset = CGPointMake(0, self.height);
        if (self.itemViews.count > 1) {
            self.scrollView.contentSize = CGSizeMake(0, self.height * 3);
        } else {
            self.scrollView.contentSize = CGSizeZero;
        }
        _currentItemFrame = CGRectMake(0, self.height, self.width, self.height);
        for (int i = 0; i < self.itemViews.count; i++) {
            UIView *view = [self.itemViews objectAtIndex:i];
            if (i != self.currentIndex) {
                view.frame = CGRectMake(0, self.frame.size.height * 3, self.width, self.height);;
            }
        }
        [self getItemAtIndex:_currentIndex].frame = _currentItemFrame;
        if (_itemViews.count == 2) {
            _nextItemFrame = CGRectMake(0, self.height * 2, self.width, self.height);
            [self getItemAtIndex:_nextIndex].frame = _nextItemFrame;
        }
    } else {
        self.scrollView.frame = self.bounds;
        self.scrollView.contentSize = CGSizeMake(self.width, self.height * _itemViews.count);
        self.scrollView.contentOffset = CGPointMake(0, _currentIndex * self.height);
        for (int i = 0; i < _itemViews.count; i ++) {
            UIView *view = [_itemViews objectAtIndex:i];
            view.frame = CGRectMake(0, i * self.height, self.width, self.height);
        }
        [self.scrollView setContentOffset:CGPointMake(0, _currentIndex * self.height) animated:NO];
    }
    [self resetIndicatorPoint];
}

- (void)nextPage {
    if (_itemViews.count > 1) {
        if (_infinite) {
            [self.scrollView setContentOffset:CGPointMake(0, self.height * 2) animated:!_forbidSlideAnimation];
        } else {
            // the currentindex will be set at the end of animation
            NSInteger nextIndex = self.currentIndex + 1;
            if(nextIndex < _itemViews.count) {
                [self.scrollView setContentOffset:CGPointMake(0, nextIndex * self.height) animated:!_forbidSlideAnimation];
            }
        }
    }
}

- (void)lastPage
{
    NSInteger lastIndex = [self currentIndex]-1;
    if (_itemViews.count > 1) {
        if (_infinite) {
            if (lastIndex < 0) {
                lastIndex = [_itemViews count]-1;
            }
        }
        [self setCurrentIndex:lastIndex];
    }
}

- (void)resetScrollView
{
    if (WXFloatEqual(self.scrollView.contentOffset.y / self.height , 1.0))
    {
        return;
    }
    [self setCurrentIndex:self.nextIndex];
    self.scrollView.contentOffset = CGPointMake(0, self.height);
}

#pragma mark Public Methods

- (void)setIndicator:(WXIndicatorView *)indicator
{
    _indicator = indicator;
    [_indicator setPointCount:self.itemViews.count];
    [_indicator setCurrentPoint:_currentIndex];
}

- (void)insertItemView:(UIView *)view atIndex:(NSInteger)index
{
    if (![self.itemViews containsObject:view]) {
        view.tag = self.itemViews.count;
        if (index < 0) {
            [self.itemViews addObject:view];
        } else {
            [self.itemViews insertObject:view atIndex:index];
        }
    }
    
    if (![self.scrollView.subviews containsObject:view]) {
        if (index < 0) {
            [self.scrollView addSubview:view];
        } else {
            [self.scrollView insertSubview:view atIndex:index];
        }
    }
    [self layoutSubviews];
    [self setCurrentIndex:_currentIndex];
}

- (void)removeItemView:(UIView *)view
{
    if ([self.itemViews containsObject:view]) {
        [self.itemViews removeObject:view];
    }
    
    if ([self.scrollView.subviews containsObject:view]) {
        [view removeFromSuperview];
    }
    [self layoutSubviews];
    [self setCurrentIndex:_currentIndex];
}

#pragma mark ScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_infinite) {
        CGFloat offY = scrollView.contentOffset.y;
        self.direction = offY > self.height ? DirectionUp : offY < self.height ? DirectionDown : DirectionNone;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(recycleSliderView:didScroll:)]) {
        [self.delegate recycleSliderView:self didScroll:self.scrollView];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.delegate scrollViewWillBeginDragging:self.scrollView];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(scrollViewDidEndDragging: willDecelerate:)]) {
        [self.delegate scrollViewDidEndDragging:self.scrollView willDecelerate:decelerate];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (_infinite) {
        [self resetScrollView];
    } else {
        NSInteger index = _scrollView.contentOffset.y / self.height;
        [self setCurrentIndex:index];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (_infinite) {
        [self resetScrollView];
    } else {
        NSInteger index = _scrollView.contentOffset.y / self.height;
        [self setCurrentIndex:index];
    }
}

@end

@interface WeexVSliderComponent () <WeexVRecycleSliderViewDelegate,WXIndicatorComponentDelegate>

@property (nonatomic, weak) WeexVRecycleSliderView *recycleSliderView;
@property (nonatomic, strong) NSTimer *autoTimer;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL  autoPlay;
@property (nonatomic, assign) NSUInteger interval;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) CGFloat lastoffsetYRatio;
@property (nonatomic, assign) CGFloat offsetYAccuracy;
@property (nonatomic, assign) BOOL  sliderChangeEvent;
@property (nonatomic, assign) BOOL  sliderScrollEvent;
@property (nonatomic, assign) BOOL  sliderScrollStartEvent;
@property (nonatomic, assign) BOOL  sliderScrollEndEvent;
@property (nonatomic, assign) BOOL  sliderStartEventFired;
@property (nonatomic, strong) NSMutableArray *childrenView;
@property (nonatomic, assign) BOOL scrollable;
@property (nonatomic, assign) BOOL infinite;
@property (nonatomic, assign) BOOL forbidSlideAnimation;

@end

@implementation WeexVSliderComponent

WX_PlUGIN_EXPORT_COMPONENT(v-slider, WeexVSliderComponent)

- (void) dealloc
{
    [self _stopAutoPlayTimer];
}

- (instancetype)initWithRef:(NSString *)ref type:(NSString *)type styles:(NSDictionary *)styles attributes:(NSDictionary *)attributes events:(NSArray *)events weexInstance:(WXSDKInstance *)weexInstance
{
    if (self = [super initWithRef:ref type:type styles:styles attributes:attributes events:events weexInstance:weexInstance]) {
        _sliderChangeEvent = NO;
        _sliderScrollEvent = NO;
        _interval = 3000;
        _childrenView = [NSMutableArray new];
        _lastoffsetYRatio = 0;
        
        if (attributes[@"autoPlay"]) {
            _autoPlay = [WXConvert BOOL:attributes[@"autoPlay"]];
        }
        
        if (attributes[@"interval"]) {
            _interval = [WXConvert NSInteger:attributes[@"interval"]];
        }
        
        if (attributes[@"index"]) {
            _index = [WXConvert NSInteger:attributes[@"index"]];
        }
        _scrollable = attributes[@"scrollable"] ? [WXConvert BOOL:attributes[@"scrollable"]] : YES;
        if (attributes[@"offsetYAccuracy"]) {
            _offsetYAccuracy = [WXConvert CGFloat:attributes[@"offsetYAccuracy"]];
        }
        _infinite = attributes[@"infinite"] ? [WXConvert BOOL:attributes[@"infinite"]] : YES;
        
        _forbidSlideAnimation = attributes[@"forbidSlideAnimation"] ? [WXConvert BOOL:attributes[@"forbidSlideAnimation"]] : NO;
        
        self.flexCssNode->setFlexDirection(WeexCore::kFlexDirectionColumn,NO);
    }
    return self;
}

- (UIView *)loadView
{
    return [[WeexVRecycleSliderView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _recycleSliderView = (WeexVRecycleSliderView *)self.view;
    _recycleSliderView.delegate = self;
    _recycleSliderView.scrollView.pagingEnabled = YES;
    _recycleSliderView.exclusiveTouch = YES;
    _recycleSliderView.scrollView.scrollEnabled = _scrollable;
    _recycleSliderView.infinite = _infinite;
    _recycleSliderView.forbidSlideAnimation = _forbidSlideAnimation;
    UIAccessibilityTraits traits = UIAccessibilityTraitAdjustable;
    if (_autoPlay) {
        traits |= UIAccessibilityTraitUpdatesFrequently;
        [self _startAutoPlayTimer];
    } else {
        [self _stopAutoPlayTimer];
    }
    _recycleSliderView.accessibilityTraits = traits;
}

- (void)layoutDidFinish
{
    _recycleSliderView.currentIndex = self.currentIndex;
}

- (void)_buildViewHierarchyLazily {
    [super _buildViewHierarchyLazily];
    _recycleSliderView.currentIndex = self.currentIndex;
}

- (void)adjustForRTL
{
    if (![WXUtility enableRTLLayoutDirection]) return;
    
    // this is scroll rtl solution.
    // scroll layout not use direction, use self tranform
    if (self.view && self.isDirectionRTL) {
        WeexVRecycleSliderView *slider = (WeexVRecycleSliderView *)self.view;
        CATransform3D transform = CATransform3DScale(CATransform3DIdentity, 1, -1, 1);
        slider.scrollView.layer.transform = transform ;
    } else {
        WeexVRecycleSliderView *slider = (WeexVRecycleSliderView *)self.view;
        slider.scrollView.layer.transform = CATransform3DIdentity ;
    }
    
}

- (void)_adjustForRTL {
    if (![WXUtility enableRTLLayoutDirection]) return;
    
    [super _adjustForRTL];
    [self adjustForRTL];
}

- (BOOL)shouldTransformSubviewsWhenRTL {
    return YES;
}

- (void)viewDidUnload
{
    [_childrenView removeAllObjects];
}

- (void)insertSubview:(WXComponent *)subcomponent atIndex:(NSInteger)index
{
    if (subcomponent->_positionType == WXPositionTypeFixed) {
        [self.weexInstance.rootView addSubview:subcomponent.view];
        return;
    }
    
    // use _lazyCreateView to forbid component like cell's view creating
    if(_lazyCreateView) {
        subcomponent->_lazyCreateView = YES;
    }
    
    if (!subcomponent->_lazyCreateView || (self->_lazyCreateView && [self isViewLoaded])) {
        UIView *view = subcomponent.view;
        
        if(index < 0) {
            [self.childrenView addObject:view];
        }
        else {
            [self.childrenView insertObject:view atIndex:index];
        }
        
        WeexVRecycleSliderView *recycleSliderView = (WeexVRecycleSliderView *)self.view;
        if ([view isKindOfClass:[WXIndicatorView class]]) {
            ((WXIndicatorComponent *)subcomponent).delegate = self;
            [recycleSliderView addSubview:view];
            [self setIndicatorView:(WXIndicatorView *)view];
            return;
        }
        
        subcomponent.isViewFrameSyncWithCalculated = NO;
        
        if (index == -1) {
            [recycleSliderView insertItemView:view atIndex:index];
        } else {
            NSInteger offset = 0;
            for (int i = 0; i < [self.childrenView count]; ++i) {
                if (index == i) break;
                
                if ([self.childrenView[i] isKindOfClass:[WXIndicatorView class]]) {
                    offset++;
                }
            }
            [recycleSliderView insertItemView:view atIndex:index - offset];
            
            // check if should apply current contentOffset
            // in case inserting subviews after layoutDidFinish
            if (index-offset == _index && _index>0) {
                recycleSliderView.currentIndex = _index;
            }
        }
        [recycleSliderView layoutSubviews];
    }
}

- (void)willRemoveSubview:(WXComponent *)component
{
    UIView *view = component.view;
    
    if(self.childrenView && [self.childrenView containsObject:view]) {
        [self.childrenView removeObject:view];
    }
    
    WeexVRecycleSliderView *recycleSliderView = (WeexVRecycleSliderView *)_view;
    [recycleSliderView removeItemView:view];
    [recycleSliderView setCurrentIndex:0];
}

- (void)updateAttributes:(NSDictionary *)attributes
{
    if (attributes[@"forbidSlideAnimation"]) {
        _forbidSlideAnimation = [WXConvert BOOL:attributes[@"forbidSlideAnimation"]];
        _recycleSliderView.forbidSlideAnimation = _forbidSlideAnimation;
    }
    
    if (attributes[@"autoPlay"]) {
        _autoPlay = [WXConvert BOOL:attributes[@"autoPlay"]];
        if (_autoPlay) {
            [self _startAutoPlayTimer];
        } else {
            [self _stopAutoPlayTimer];
        }
    }
    
    if (attributes[@"interval"]) {
        _interval = [WXConvert NSInteger:attributes[@"interval"]];
        [self _stopAutoPlayTimer];
        
        if (_autoPlay) {
            [self _startAutoPlayTimer];
        }
    }
    
    if (attributes[@"index"]) {
        _index = [WXConvert NSInteger:attributes[@"index"]];
        self.currentIndex = _index;
        self.recycleSliderView.currentIndex = _index;
    }
    
    if (attributes[@"scrollable"]) {
        _scrollable = attributes[@"scrollable"] ? [WXConvert BOOL:attributes[@"scrollable"]] : YES;
        ((WeexVRecycleSliderView *)self.view).scrollView.scrollEnabled = _scrollable;
    }
    
    if (attributes[@"offsetYAccuracy"]) {
        _offsetYAccuracy = [WXConvert CGFloat:attributes[@"offsetYAccuracy"]];
    }
    if (attributes[@"infinite"]) {
        _infinite = [WXConvert BOOL:attributes[@"infinite"]];
    }
}

- (void)addEvent:(NSString *)eventName
{
    if ([eventName isEqualToString:@"change"]) {
        _sliderChangeEvent = YES;
    }
    if ([eventName isEqualToString:@"scroll"]) {
        _sliderScrollEvent = YES;
    }
}

- (void)removeEvent:(NSString *)eventName
{
    if ([eventName isEqualToString:@"change"]) {
        _sliderChangeEvent = NO;
    }
    if ([eventName isEqualToString:@"scroll"]) {
        _sliderScrollEvent = NO;
    }
}

- (BOOL)requestGestureShouldStopPropagation:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return [self gestureShouldStopPropagation:gestureRecognizer shouldReceiveTouch:touch];
}

#pragma mark WXIndicatorComponentDelegate Methods

-(void)setIndicatorView:(WXIndicatorView *)indicatorView
{
    NSAssert(_recycleSliderView, @"");
    [_recycleSliderView setIndicator:indicatorView];
}

- (void)resumeAutoPlay:(id)resume
{
    if (_autoPlay) {
        if ([resume boolValue]) {
            [self _startAutoPlayTimer];
        } else {
            [self _stopAutoPlayTimer];
        }
    }
}

#pragma mark Private Methods

- (void)_startAutoPlayTimer
{
    if (!self.autoTimer || ![self.autoTimer isValid]) {
        __weak __typeof__(self) weakSelf = self;
        self.autoTimer = [NSTimer wx_scheduledTimerWithTimeInterval:_interval/1000.0f block:^() {
            [weakSelf _autoPlayOnTimer];
        } repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.autoTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)_stopAutoPlayTimer
{
    if (self.autoTimer && [self.autoTimer isValid]) {
        [self.autoTimer invalidate];
        self.autoTimer = nil;
    }
}

- (void)_autoPlayOnTimer
{
    if (!_infinite && (_currentIndex == _recycleSliderView.itemViews.count - 1)) {
        [self _stopAutoPlayTimer];
    }else {
        [self.recycleSliderView nextPage];
    }
}

#pragma mark ScrollView Delegate

- (void)recycleSliderView:(WeexVRecycleSliderView *)recycleSliderView didScroll:(UIScrollView *)scrollView
{
    if (_sliderScrollEvent) {
        CGFloat height = scrollView.frame.size.height;
        CGFloat YDeviation = 0;
        if (_infinite) {
            YDeviation = - (scrollView.contentOffset.y - height);
        } else {
            YDeviation = - (scrollView.contentOffset.y - height * _currentIndex);
        }
        CGFloat offsetYRatio = (YDeviation / height);
        if (fabs(offsetYRatio - _lastoffsetYRatio) >= _offsetYAccuracy) {
            _lastoffsetYRatio = offsetYRatio;
            [self fireEvent:@"scroll" params:@{@"offsetYRatio":[NSNumber numberWithFloat:offsetYRatio]} domChanges:nil];
        }
    }
}

- (void)recycleSliderView:(WeexVRecycleSliderView *)recycleSliderView didScrollToItemAtIndex:(NSInteger)index
{
    if (_sliderChangeEvent) {
        [self fireEvent:@"change" params:@{@"index":@(index)} domChanges:@{@"attrs": @{@"index": @(index)}}];
    }
    self.currentIndex = index;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self _stopAutoPlayTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (_autoPlay) {
        [self _startAutoPlayTimer];
    }
}

@end

@implementation WeexVRecycleSliderScrollView
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    WeexVRecycleSliderView *view = (WeexVRecycleSliderView *)self.delegate;
    if (![view isKindOfClass:[UIView class]]) {
        return YES;
    }
    
    if ([(id <WeexVRecycleSliderViewDelegate>) view.wx_component respondsToSelector:@selector(requestGestureShouldStopPropagation:shouldReceiveTouch:)]) {
        return [(id <WeexVRecycleSliderViewDelegate>) view.wx_component requestGestureShouldStopPropagation:gestureRecognizer shouldReceiveTouch:touch];
    }
    else{
        return YES;
    }
}

@end
