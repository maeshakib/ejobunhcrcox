<?php

namespace App\Http\Controllers;

use DB;
use Validator;
use DateTime;
use DatePeriod;
use DateInterval;
use App\UserAttendance;
use App\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class UserAttendanceController extends Controller
{
    public function checkin(Request $request)
    {
        $user = auth('api')->user()->id;
        $now = date("Y-m-d");
        $cin = date("H:i:s");
        //return $now;
        $rules = array(
            'cin_latlng' => 'present',
            'cin_area' => 'present',
            'remarks' => 'present',
            'date' => Rule::unique('user_attendances')->where(function ($query) use($user,$now) {
                        $query->where('user_id', $user);
                        $query->whereDate('date', $now);
                }),
            
        );
        $messages=array(
            'date.unique' => 'You have already Checked in',
        );
        $request->request->add(['date' => $now]);
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors()->all()[0],
            'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        //$user = auth('api')->user();
        $attendance = new UserAttendance;
        $attendance->date = $now;
        $attendance->user_id = $user;
        $attendance->cin_time = $cin;
        $attendance->cin_latlng = $request->cin_latlng;
        $attendance->cin_area = $request->cin_area;
        $attendance->remarks = $request->remarks;
        $attendance->save();

        $returnMessage = array(
            'success' => true,
            'errors' => null,
            'message'       => 'Checked In!'
            
            );
            return response()->json($returnMessage, 200);



        
        
    }



    public function checkout(Request $request)
    {
        $user = auth('api')->user()->id;
        $now = date("Y-m-d");
        $cout = date("H:i:s");
        //return $now;
        $rules = array(
            'cout_latlng' => 'present',
            'cout_area' => 'present',
            'remarks' => 'present',
            'date' => Rule::exists('user_attendances')->where(function ($query) use($user,$now) {
                        $query->where('user_id', $user);
                        $query->where('cout_time', null);
                        $query->whereDate('date', $now);
                }),
        );
        $messages=array(
            'date.exists' => 'Cannot Checkout Again!!',
        );
        $request->request->add(['date' => $now]);
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors()->all()[0],
            'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        //$user = auth('api')->user();
        $attendance = UserAttendance::where('user_id', $user)->whereDate('date', $now)->first();

        $attendance->cout_time = $cout;
        $attendance->cout_latlng = $request->cout_latlng;
        $attendance->cout_area = $request->cout_area;
        $attendance->remarks = $request->remarks;
        $attendance->save();

        $returnMessage = array(
            'success' => true,
            'errors' => null,
            'message'       => 'Checked Out!'
            
            );
            return response()->json($returnMessage, 200);
        
    }


    /*
    *
    *
    *
    */
    public function history()
    {
        $user = auth('api')->user()->id;
        $now = date("Y-m-d");
        $before = date('Y-m-d', strtotime('-30 days'));
        $attendance = UserAttendance::where('user_id', $user)
                                    ->whereBetween('date', [$before, $now])
                                    ->orderBy('date','DESC')
                                    ->get();

        
        return response()->json($attendance, 200);
        
    }


    /*
    *
    *
    *
    */

    public function attendanceSummery()
    {
        $user = auth('api')->user();
        $today = date("Y-m-d");
        $checkin = UserAttendance::where('user_id', $user->id)->whereDate('date', $today)->first(['cin_time', 'cout_time']);
        $summery = DB::select('select  day(last_day(NOW())) - (SELECT COUNT(*) FROM calendar_holidays 
        WHERE YEAR(holiday_date) = YEAR(NOW()) && MONTH(holiday_date) = MONTH(NOW())) as Working_days,
        (SELECT COUNT(*) FROM user_attendances ua 
        WHERE YEAR(ua.date) = YEAR(NOW()) && MONTH(ua.date) = MONTH(NOW()) && ua.user_id = ?) -
        (SELECT count(*) FROM user_attendances ua 
        JOIN leave_applications l on ua.user_id = l.user_id AND l.is_approved = 1 AND ua.date BETWEEN l.from_date AND l.to_date 
        WHERE YEAR(ua.date) = YEAR(NOW()) && MONTH(ua.date) = MONTH(NOW()) && ua.user_id = ?)
         AS present_days',[$user->id, $user->id]);

        $history = DB::select('SELECT COUNT(*) -
        (SELECT count(*) FROM user_attendances u 
        JOIN leave_applications l on u.user_id = l.user_id AND l.is_approved = 1 AND u.date BETWEEN l.from_date AND l.to_date 
        WHERE YEAR(u.date) = YEAR(ua.date) && MONTH(u.date) = MONTH(ua.date) && u.user_id = ua.user_id)
        as attended, 
        MONTHNAME(ua.date) as month_name, 
        MONTH(ua.date) as month_number, 
        YEAR(ua.date) as year FROM user_attendances ua WHERE ua.user_id = ?
        GROUP BY EXTRACT(YEAR_MONTH from ua.date)
        ORDER BY  EXTRACT(YEAR_MONTH from ua.date) desc',[$user->id]);

        $data = array(
            'success' => true,
            'summery' => reset($summery),
            'history' => $history,
            'checkin' => $checkin
        );

        
        return response()->json($data, 200);
        
    }

    /*
    *
    *
    *
    */

    public function monthlyAttendaceDetails(Request $request)
    {
        $rules = array(
            'date' => 'required|date'
        );
        $messages=array(
            'date.required' => 'Month And Year Required',
        );
        
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors()->all()[0],
            'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        $user = auth('api')->user();
        $attendance = DB::select('CALL MonthlyAttendanceList(?,?);',[$request->date, $user->id]);

        return response()->json($attendance, 200);
        
    }

    /*
    *
    *
    *
    */

    public function locationSync(Request $request)
    {
        $rules = array(
            'latlng' => 'required',
            'area' => 'required',
        );
        $messages=array(
            'area.required' => 'Area is Required',
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors()->all()[0],
            'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        $user = auth('api')->user()->id;
        $today = date("Y-m-d");
        $now = date("H:i:s");
        $attendance = UserAttendance::where('user_id', $user)->whereDate('date', $today)->first();
        $arr[] = floatval(explode(',' , $request->latlng)[0]);
        $arr[] = floatval(explode(',' , $request->latlng)[1]);
        if($attendance){
            $newLocation = array(
                'latlng' => $arr,
                'area' => $request->area,
                'time' => $now
            );

            $c = collect(json_decode($attendance->locations));
            $c->push($newLocation);

            $attendance->locations = $c->toJson();
            $attendance->save();
            $returnMessage = array(
                'success' => true,
                'message' => 'Saved'

                );
            return response()->json($returnMessage, 200);
        }
        $returnMessage = array(
            'success' => false,
            'message' => 'Not Checked in Yet!!'
            );
        return response()->json($returnMessage, 200);
        
        
    }

    /*
    *
    *
    *
    */

    public function dailyActivityMonitor(Request $request)
    {
        $rules = array(
            'date' => 'required|date',
            'location_area_id' => 'required|exists:location_areas,id',
        );
        $messages=array(
            'location_area_id.required' => 'Area is Required',
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        $user = auth('api')->user()->id;

        $data = DB::select('SELECT ua.*, u.name, u.photo from user_attendances ua
        join users u ON ua.user_id = u.id 
        WHERE ua.user_id IN (
            select p1.id as user_id
                from        users p1
            	join location_areas l on p1.location_area_id = l.id
                left join   users p2 on p2.id = p1.supervisor_id
                left join   users p3 on p3.id = p2.supervisor_id 
                left join   users p4 on p4.id = p3.supervisor_id  
                left join   users p5 on p5.id = p4.supervisor_id  
                left join   users p6 on p6.id = p5.supervisor_id
                where  l.id = :user_location AND :admin_id in (p1.supervisor_id, 
                                    p2.supervisor_id, 
                                    p3.supervisor_id, 
                                    p4.supervisor_id, 
                                    p5.supervisor_id, 
                                    p6.supervisor_id))
                AND ua.date = :date',['date' => $request->date, 'user_location' => $request->location_area_id, 'admin_id' => $user]);
        $returnMessage = array(
            'success' => true,
            'attendance' => $data
        );
        return response()->json($returnMessage, 200);
        //return $attendances;
    }

}
