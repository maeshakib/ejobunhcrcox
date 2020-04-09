<?php

namespace App\Http\Controllers;


use Validator;
use App\SpecialTraining;

use Illuminate\Validation\Rule;
use Illuminate\Http\Request;



class SpecialTrainingController extends Controller
{
   


    
    public function index()
    {
        //get all departments
        $training= SpecialTraining::all();
        if ($training)
        {
            return response()->json([
                'success' => true,
                'trainings' => $training
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no data found'
                ], 500);
            }

    }
    //end index fuction

    

    public function store(Request $request)
    {
 
      //  return $request;
        $user= auth('api')->user();
        $rules = array(
            'course_title' => 'required',
            'school_name' => 'required',                              
        );
        $messages=array(
            'course_title.required' => 'Course title required',
            'school_name.required' => 'Please enter a school name.',           
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            );
            return response()->json($returnMessage, 200);
        }


        $training_sv = new SpecialTraining;
        $training_sv->course_title = $request->course_title;
        $training_sv->school_name = $request->school_name;  
        $training_sv->country = $request->country;
        $training_sv->course_start_date = $request->course_start_date;  
        $training_sv->course_end_date = $request->course_end_date;
        $training_sv->topic_area = $request->topic_area;  
        $training_sv->training_methodology = $request->training_methodology;  
        $training_sv->course_description = $request->course_description;  

        $training_sv->jobseeker_id = $user->id;       
        $training_sv->created_at   = now();
        $saved=$training_sv->save();

        if ($saved)
        {
          return response()->json([
                'success' => true,
            ], 200);
        }




    }
//end store function


public function show($id)
{
    $training_detail = SpecialTraining::find($id);


    if (!$training_detail) 
    {
        return response()->json([
            'success' => false,
            'message' => 'Sorry, Training Details with id ' . $id . ' cannot be found'
        ], 400);
    }else
    {
        return response()->json($training_detail);
    }

}
//end show





public function update(Request $request, $id)
{
    $rules = array(
        'course_title' => 'required',
        'school_name' => 'required',                              
    );
    $messages=array(
        'course_title.required' => 'Course title required',
        'school_name.required' => 'Please enter a school name.',           
    );
    
    $validator = Validator::make($request->all(), $rules, $messages);
    if($validator->fails())
    {
        $returnMessage = array(
        'success' => false,
        'errors' => $validator->errors(),
        );
        return response()->json($returnMessage, 403);
    }
    
    $training = SpecialTraining::find($id);
    if (!$training) {
        return response()->json([
            'success' => false,
            'message' => 'Sorry, Training detail with id ' . $id . ' cannot be found'
        ], 400);
    }


    // $updated = $reference->fill($request->all())
    // ->save();





    $training->course_title = $request->course_title;
    $training->school_name = $request->school_name;  
    $training->country = $request->country;
    $training->course_start_date = $request->course_start_date;  
    $training->course_end_date = $request->course_end_date;
    $training->topic_area = $request->topic_area;  
    $training->training_methodology = $request->training_methodology;  
    $training->course_description = $request->course_description;  

    $training->created_at   = now();
    $updated=$training->save();



    if ($updated) {
        return response()->json([
            'success' => true
        ]);
    } else {
        return response()->json([
            'success' => false,
            'message' => 'Sorry, Training could not be updated'
        ], 500);
    }




}








} //end class
