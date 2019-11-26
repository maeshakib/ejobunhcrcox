<?php

namespace App\Http\Controllers;

use DB;
use Validator;
use DateTime;
use App\CalendarHoliday;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CalendarHolidayController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index(Request $request)
    {
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after:from_date'
        );
        $messages=array(
            'from_date.required' => 'from date required',
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
        //$date = new DateTime($request->date);
        $holidays = CalendarHoliday::whereBetween('holiday_date', [$request->from_date, $request->to_date])
                                    ->orderBy('holiday_date')
                                    ->get(['holiday_date','holiday_name']);
        return response()->json( $holidays, 200);
       
        //$holidays = CalendarHolidays::
    }

    /**
     * Store a newly created resource in storage.
     *
     * array of holidays
     */
    public function store(Request $request)
    {
        $rules = array(
            'holidays' => 'required|array',
            'holidays.*.holiday_date' => 'required|date|distinct|unique:calendar_holidays',
            'holidays.*.holiday_name' => 'required'
        );
        $messages=array(
            'holidays.*.holiday_date.required' => 'Date required',
            'holidays.*.holiday_date.unique' => 'Duplicate Date Entry Detected!!',
        );
        //return $request->all();
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
        //return $request->data;
        $created = CalendarHoliday::insert($request->holidays);
        $returnMessage = array(
            'success' => true,
            'saved' => $created
        );
        return response()->json($returnMessage, 200);
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(Request $request)
    {
        $rules = array(
            'from_date' => 'required',
            'to_date' => 'required|after:from_date',
            'holidays' => 'array',
            'holidays.*.holiday_date' => 'filled|date|distinct|after_or_equal:from_date|before_or_equal:to_date',
            'holidays.*.holiday_name' => 'filled'
        );
        $messages=array(
            'holidays.*.holiday_date.required' => 'Date required',
            'holidays.*.holiday_date.unique' => 'Duplicate Date Entry Detected!!',
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
        $collection = collect($request->holidays);
        $storedHolidays = CalendarHoliday::whereBetween('holiday_date', [$request->from_date, $request->to_date])
                                    ->orderBy('holiday_date')
                                    ->get(); 
        $deletedList =  $storedHolidays->whereNotIn('holiday_date',array_column($request->holidays,'holiday_date'))->pluck('holiday_date');
        $editList = $collection->whereIn('holiday_date',array_column($storedHolidays->toArray(),'holiday_date'));
        $newList = $collection->whereNotIn('holiday_date',array_column($storedHolidays->toArray(),'holiday_date'))->values();
        
        foreach ($editList as $update) {
            DB::table('calendar_holidays')
            ->where('holiday_date', $update['holiday_date'])
            ->update(['holiday_name' => $update['holiday_name']]);
        }
        $created = CalendarHoliday::insert($newList->toArray());
        $deleted = DB::table('calendar_holidays')->whereIn('holiday_date', $deletedList)->delete();
       
        $returnMessage = array(
            
            'success' => true,
            'saved' => $storedHolidays->pluck('holiday_date'),
            'requested' => $collection->pluck('holiday_date'),
            'deleted' => $deletedList,
            'edited' => $editList,
            'new'       => $newList,
            'test' => $created
            
            );
        
        return response()->json($returnMessage, 200);
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        //
    }
}
