<?php

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
 */

// Route::middleware('auth:api')->get('/user', function (Request $request) {
//     return $request->user();
// });



Route::post('sign-up', 'UserLoginController@signup');
Route::post('login', 'UserLoginController@login');
Route::post('logout', 'UserLoginController@logout');
Route::get('all-jobs', 'JobDetail@index');
Route::get('single-job/{id}', 'JobDetail@show');
Route::post('send', 'UserLoginController@send');



Route::group(['middleware' => ['api']], function () {
    Route::get('myprofile', 'UserLoginController@myProfile');//1
    Route::post('profile/update', 'UserLoginController@profileUpdate');//1
    Route::get('user-permissions-list', 'UserLoginController@userPermissionListData');
    


});
Route::group(['middleware' => ['api', 'permissions']], function () {


    Route::put('file-upload/{id}', 'JobseekerPersonalInfoController@fileupload');
    Route::put('photo-upload/{id}', 'JobseekerPersonalInfoController@photoFileupload');

    Route::apiResource('job-post', 'JobPostController');
    Route::post('short-list-user', 'JobPostController@shortListUser');

    
    Route::get('job-cv/{id}', 'JobPostController@singleJobAllCv');
    Route::get('job-cv-shortlist/{id}', 'JobPostController@singleJobShortlistedCv');

    
    
    Route::post('applied-jobs/{id}', 'JobAppliedController@store');
    Route::get('applied-jobs', 'JobAppliedController@index');

    Route::apiResource('training', 'SpecialTrainingController');
    Route::apiResource('personal-details', 'JobseekerPersonalInfoController');
    Route::apiResource('reference', 'ReferenceController');
    Route::apiResource('education', 'EducationController');
    Route::apiResource('work-experience', 'WorkExperienceController');





    //Role management routes
    Route::resource('roles', 'RoleController');
    //delete Role and replace all user
    Route::post('role/{id}', 'RoleController@destroy');

    //AdminController routes
    Route::post('user-list', 'AdminController@index');
    Route::get('create-user', 'AdminController@create');
    Route::post('create-user', 'AdminController@store');
    Route::get('user-edit/{id}', 'AdminController@edit');
    Route::post('user-edit/{id}', 'AdminController@update');
    Route::post('delete-user/{id}', 'AdminController@destroy');

    Route::apiResource('locations', 'LocationAreaController');
    Route::get('location_levels', 'LocationAreaController@levelDD');
    Route::get('getlevels/{id}', 'LocationAreaController@getlevel');
    Route::get('getlocation', 'LocationAreaController@getlocation_self');
    Route::get('getlocation/{id}', 'LocationAreaController@getlocation');
    Route::get('getLevelwiseLocation/{id}', 'LocationAreaController@getLevelwiseLocation');
    Route::get('getlocationwithlevel/{id}', 'LocationAreaController@getlocationWithLevel');
    Route::get('getlocationwithlevel', 'LocationAreaController@getlocationWithLevel_self');
    Route::get('location_parents/{id}', 'LocationAreaController@getLocationParents');


    
     Route::apiResource('department', 'DepartmentController');
     Route::apiResource('depot', 'DepotController');
     Route::apiResource('designation', 'DesignationController');
     Route::apiResource('meeting', 'MeetingController');
     Route::get('user_suggestion', 'MeetingController@userSuggestion');
     Route::post('meeting_list', 'MeetingController@meetingList');
     Route::apiResource('clients', 'ClientController');
     Route::apiResource('sales', 'SaleController');
     Route::post('sales', 'SaleController@index');
     Route::post('sales-store', 'SaleController@store');
     Route::post('test', 'SaleController@test');
     Route::post('add_collection/{id}', 'SaleController@addCollection');
     Route::post('single-client-sales', 'SaleController@singleClientSales');

     Route::post('get_holidays', 'CalendarHolidayController@index');
    Route::post('insert_holidays', 'CalendarHolidayController@store');
    Route::post('update_holidays', 'CalendarHolidayController@update');

    Route::post('checkin', 'UserAttendanceController@checkin');
    Route::post('checkout', 'UserAttendanceController@checkout');
    Route::get('checkin_history', 'UserAttendanceController@history');
    Route::post('location_sync', 'UserAttendanceController@locationSync');
    Route::get('current_attendance_summery', 'UserAttendanceController@attendanceSummery');
    Route::post('monthly_attendance_details', 'UserAttendanceController@monthlyAttendaceDetails');
    Route::post('user_activity_monitor', 'UserAttendanceController@dailyActivityMonitor');

    Route::resource('target', 'TargetController');
    Route::post('target_list', 'TargetController@index');
    Route::post('target_user', 'TargetController@userTarget');
    Route::post('target_self', 'TargetController@selfTarget');
    Route::post('get_target_user_months', 'TargetController@getMonthListforUserTarget');


    Route::post('mio_activity', 'ReportingController@MIO_activity');

    Route::get('reset-password/{token}', 'UserLoginController@resetPassword');
 
    Route::post('all-sales', 'ReportingController@getAllSales');
    Route::post('all-collections', 'ReportingController@getAllCollections');
    Route::post('am-sales', 'ReportingController@aMWiseSales');
    Route::post('am-collections', 'ReportingController@aMWiseCollections');

});
//end middleware
