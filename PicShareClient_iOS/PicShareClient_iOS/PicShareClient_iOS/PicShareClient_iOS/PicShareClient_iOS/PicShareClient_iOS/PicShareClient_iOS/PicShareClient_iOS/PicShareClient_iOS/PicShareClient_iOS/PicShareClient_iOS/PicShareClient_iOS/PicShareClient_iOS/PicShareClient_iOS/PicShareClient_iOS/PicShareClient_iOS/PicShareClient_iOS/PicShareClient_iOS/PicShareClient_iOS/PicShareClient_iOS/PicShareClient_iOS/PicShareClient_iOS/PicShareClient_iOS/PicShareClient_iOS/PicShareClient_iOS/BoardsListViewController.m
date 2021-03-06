//
//  BoardsListViewController.m
//  PicShareClient_iOS
//
//  Created by 和光 缪 on 12-3-5.
//  Copyright (c) 2012年 Shanghai University. All rights reserved.
//

#import "BoardsListViewController.h"
#import "PicShareEngine.h"
#import "BoardsListCell.h"
#import "PicDetailViewController.h"

@interface BoardsListViewController ()

-(void)loadData;
-(void)loadDataDidFinish:(NSArray *)data;
-(void)pageData;
-(void)pageDataDidFinish:(NSArray *)data;

@end

@implementation BoardsListViewController

@synthesize boards = _boards;
@synthesize type = _type;
@synthesize contentId = _contentId;
- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(id)initWithType:(TheType)aType AndId:(NSInteger)anId
{
    self = [super init];
    if(self){
        _type = aType;
        _contentId = anId;
        _currPage = 1;
        _hasNext = NO;
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    _oprationq = [[NSOperationQueue alloc]init];
    [self startLoading];

    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.boards = nil;
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc
{
    [_boards release];
    [_oprationq release];
    [_indicator release];
    [super dealloc];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_boards.count!=0) {
        return _boards.count+1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *normalCellIdentifier = @"normalCell";
    static NSString *moreCellIdentifier = @"moreCell";
    static NSString *paginationCellIdentifier = @"pagingCell";
    //pagination cell
    if (indexPath.row == _boards.count) {
        
        UITableViewCell *cell =[tableView dequeueReusableCellWithIdentifier:paginationCellIdentifier];
        if (cell==nil) {
            cell = [[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:paginationCellIdentifier]autorelease];
        }
        if (_hasNext) {
            cell.textLabel.text = @"更多...";
        }
        else {
            cell.textLabel.text=@"";
        }
        
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        return cell;
    }
    //pagination end
    
    
    NSString *CellIdentifier;
    Board *b = [_boards objectAtIndex:indexPath.row];
    NSArray *pictureStatuses = b.pictureStatuses;
    int imagesCount = pictureStatuses.count;
    if (imagesCount>8) {
        CellIdentifier = moreCellIdentifier;
    }
    else {
        CellIdentifier = normalCellIdentifier;
    }
    
    BoardsListCell *cell = (BoardsListCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell==nil) {
        cell = [[[BoardsListCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier]autorelease];
    }
    cell.boardNameLabel.text = b.name;
    cell.picCountLabel.text = [[[NSString alloc]initWithFormat:@"%d张图片",b.picturesCount]autorelease];
    cell.eventDelegate = self;
    [cell clearCurrentPictures];
    if (imagesCount>8) {
        for (int i=0; i<7; i++) {
            PictureStatus *ps = [pictureStatuses objectAtIndex:i];
            [cell addPictureWithUrlStr:ps.pictureUrl];
        }
//        UIButton *moreButton = [[UIButton alloc]initWithFrame:CGRectMake(244, 125,60, 60)];
//        [moreButton setTitle:@"更多..." forState:UIControlStateNormal];
//        [moreButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
//        [moreButton setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
//        [cell.contentView addSubview:moreButton];
//        [moreButton release];
    }
    else {
        for (int i=0; i<imagesCount; i++) {
            PictureStatus *ps = [pictureStatuses objectAtIndex:i];
            [cell addPictureWithUrlStr:ps.pictureUrl];
        }
    }
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row==_boards.count) {
        return 40;
    }
    return [BoardsListCell getBoardsListCellHeight:[_boards objectAtIndex:indexPath.row] withSpecifiedOrientation:nil];
}

#pragma mark - pullRefresh method

-(void)refresh
{
    NSInvocationOperation *downloadOperation = [[NSInvocationOperation alloc]initWithTarget:self selector:@selector(loadData) object:nil];
    [_oprationq addOperation:downloadOperation];
    isLoadingData = YES;
    [downloadOperation release];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == _boards.count) {
        //add more
        if (!isLoadingData) {
            NSInvocationOperation *pageOpreration = [[NSInvocationOperation alloc]initWithTarget:self selector:@selector(pageData) object:nil];
            [_oprationq addOperation:pageOpreration];
            [pageOpreration release];
        }
    }
}

#pragma mark - async methods

-(void)loadData
{
    _engine = [PicShareEngine sharedEngine];
    NSArray *returnedArray = nil;
    if (_type == categoryDetail) {
        returnedArray = [_engine getBoardsOfCategoryId:_contentId];
    }else {
        returnedArray = [_engine getBoardsOfUserId:_contentId];
    }
    [self performSelectorOnMainThread:@selector(loadDataDidFinish:) withObject:returnedArray waitUntilDone:NO];
}

-(void)loadDataDidFinish:(NSArray *)data
{
    NSMutableArray *mutableBoardsData = [[NSMutableArray alloc]initWithArray:[data subarrayWithRange:NSMakeRange(1, data.count-1)]];
    self.boards = mutableBoardsData;
    [mutableBoardsData release];
    if ([[data objectAtIndex:0]intValue]==1) {
        _hasNext = YES;
    }
    else {
        _hasNext = NO;
    }
    isLoadingData = NO;
    [self stopLoading];
    _currPage = 1;
    [self.tableView reloadData];
}

- (void)pageData
{
    _engine = [PicShareEngine sharedEngine];
    NSArray *returnedArray = nil;
    if (_type == categoryDetail) {
       returnedArray = [_engine getBoardsOfCategoryId:_contentId page:++_currPage];
    }else{
        returnedArray = [_engine getBoardsOfUserId:_contentId page:++_currPage];
    }
    [self performSelectorOnMainThread:@selector(pageDataDidFinish:) withObject:returnedArray waitUntilDone:NO];
}

- (void)pageDataDidFinish:(NSArray *)data
{
    NSArray *boardsData = [data subarrayWithRange:NSMakeRange(1, data.count-1)];
    int originBoardsCount = _boards.count;
    for (Board *aBoard in boardsData) {
        [_boards insertObject:aBoard atIndex:originBoardsCount++];
    }
    if ([[data objectAtIndex:0]intValue]==1) {
        _hasNext = YES;
    }
    else {
        _hasNext = NO;
    }
    [self.tableView reloadData];
}

#pragma mark - PSThumbnailImageViewDelegate
- (void)didReceiveTouchEvent:(id)sender
{
    PSThumbnailImageView *iv = (PSThumbnailImageView *)sender;
    BoardsListCell *cell = (BoardsListCell *)iv.superview.superview.superview;//Imageview->scrollview->contentview->cell
    NSIndexPath *index = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    NSInteger offset = [cell offsetOfaThumbnail:iv];
    Board *b = [_boards objectAtIndex:index.row];
    PictureStatus *ps = [b.pictureStatuses objectAtIndex:offset];
    //NSLog(@"iv at row %d, offset: %d",index.row,offset);
    //PicDetailViewController *picDetailViewController = [[PicDetailViewController alloc]initWithNibName:@"PicDetailViewController" bundle:[NSBundle mainBundle]];
    PicDetailViewController *picDetailViewController = [[PicDetailViewController alloc]initWithPicId:ps.psId];
    [self.navigationController pushViewController:picDetailViewController animated:YES];
    [picDetailViewController release];
}

@end
