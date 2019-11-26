<?php

namespace App\Http\Controllers;
use App\Education;
use Validator;
use Illuminate\Http\Request;

class EducationController extends Controller
{
    public function index()
    {
        //get all departments
        $all_references = Reference::all();
        if ($all_references)
        {
            return response()->json([
                'success' => true,
                'references' => $all_references
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no reference found'
                ], 500);
            }

    }



    public function store(Request $request)
    {
      //  return $request;
        $user= auth('api')->user();
        $rules = array(
            'degree_title' => 'required|max:190',
            'begin_date' => 'required|max:190',
            'end_date' => 'required|max:190',
            'level_of_education' => 'required|max:190',

            'school_name' => 'required|max:190',

            
        );
        $messages=array(
            'degree_title.required' => 'Please enter a Name.',
            'begin_date.required' => 'Please enter a Title.',
            'end_date.required' => 'Please enter a Employeer.',
            'level_of_education.required' => 'Please enter a Employeer.',

            'school_name.required' => 'Please enter a Employeer.',

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
        $education = new Education;
        $education->degree_title = $request->degree_title;
        $education->begin_date = $request->begin_date;
        $education->end_date = $request->end_date;
        $education->jobseeker_id = $user->id;
        $education->level_of_education = $request->level_of_education;
        $education->school_name = $request->school_name;
        $education->created_at   = now();

        $saved=$education->save();

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
        $reference = Reference::find($id);


        if (!$reference) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Reference with id ' . $id . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json($reference);
        }

    }
    //end show

    
    public function update(Request $request, $id)
    {
        $rules = array(
            'reference_name' => 'required|max:190',
            'title' => 'required|max:190',
            'employer' => 'required|max:190',
        );
        $messages=array(
            'reference_name.required' => 'Please enter a Name.',
            'title.required' => 'Please enter a Title.',
            'employer.required' => 'Please enter a Employeer.',
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
        
        $reference = Reference::find($id);
        if (!$reference) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Reference with id ' . $id . ' cannot be found'
            ], 400);
        }


        // $updated = $reference->fill($request->all())
        // ->save();

        $reference->reference_name = $request->reference_name;
        $reference->title = $request->title;
        $reference->employer = $request->employer;
        $reference->email_address = $request->email_address;
        $reference->address_line_one = $request->address_line_one;
  
        $updated = $reference->save();


        if ($updated) {
            return response()->json([
                'success' => true
            ]);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Reference could not be updated'
            ], 500);
        }




    }

}
