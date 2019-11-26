<?php

namespace App\Http\Controllers;

use Validator;
use Illuminate\Http\Request;
use App\User;
use App\Meeting;
use App\MeetingDetail;
use App\MeetingParticipant;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use DB;
use JWTAuth;

class MeetingController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
      
       $user= auth('api')->user();
        $meetings = Meeting::whereHas('participants', function ($query) use($user) {
            $query->where('user_email', $user->email);
        })
        ->with('participants.user:id,email,photo')
        ->get();
        return $meetings;
    }

    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function meetingList(Request $request)
    {
        $rules = array(
            'type'       => 'required|numeric|between:0,2', // 0 = upcoming, 1 = success, 2 = cancelled
        );
        $messages=array(
            'type.required' => 'Please enter a Type.'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
            );
            return response()->json($returnMessage, 200);
        }
       $user= auth('api')->user();
       $today = date('Y-m-d');
        $meetings = Meeting::whereHas('participants', function ($query) use($user) {
            $query->where('user_email', $user->email);
        })
        ->when($request->type == 0,function ($query, $today) {
            return $query->where('to_date', '>=', $today);
        })
        ->when($request->type == 1,function ($query) {
            return $query->where('meeting_status', 1);
        })
        ->when($request->type == 2,function ($query) {
            return $query->where('meeting_status', 2);
        })
        ->with('participants.user:id,email,photo')
        ->orderBy('from_date', 'desc')
        ->take(30)
        ->get();
        $data['success'] = true;
        $data['meetings'] = $meetings;
        return $data;
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $reqParticipants = null;
        if($request->has('participants')){
            $reqParticipants = json_decode($request->participants);
        }
        //return $request->all();
        //return response()->json($request->all(), 200);

        $rules = array(
            'title'       => 'required|max:255',
            'from_date'       => 'required|date',
            'to_date'       => 'required|date|after:from_date',
            'repeat' => [
                'required',
                Rule::in([0, 1]),
            ],
            'type' => 'required|integer',
            'meeting_status' => 'required|integer', // 0 = active, 1= success, 2 = cancelled
            'published' => [
                'required',
                Rule::in([0, 1]),
            ],
            'created_for' => 'nullable|exists:users,id',
            'participants' => 'filled',
            //'participants.*.user_email' => 'filled|email|distinct',
            //'participants.*.name' => 'required_with:participants.*.user_email',
        );

        $messages=array(
            'title.required' => 'Please enter a Title.'
        );

        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
            
            );
            
            return response()->json($returnMessage, 200);
        }
        $user= auth('api')->user();
        if(!$request->created_for || $request->created_for == 0){
            $request['created_for'] = $user->id;
        }
        //return $request->all();
        $meetingIds = [];
        
        $filePath = null;
        $imagePath = null;
        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $name =  'file_'.uniqid().'.'.$request->file->getClientOriginalExtension();
            $destinationPath = public_path('/meeting');
            $file->move($destinationPath, $name);
            $filePath = "meeting/".$name;
        }
        if ($request->hasFile('image')) {
            $image = $request->file('image');
            $name =  'img_'.uniqid().'.'.$image->getClientOriginalExtension();
            $destinationPath = public_path('/meeting');
            $image->move($destinationPath, $name);
            $imagePath = "meeting/".$name;
        }
        $created_for = User::find($request->created_for);
        
        $begin = new \DateTime($request->from_date);
        $end = new \DateTime($request->to_date);
        if ($request->repeat == 1) 
        {
            $now = date("Y-m-d H:i:s");
            $daterange = new \DatePeriod($begin, new \DateInterval('P1D'), $end);
            foreach($daterange as $date){
                $meeting = new Meeting;
                $meeting->fill($request->only([
                    'title',
                    'repeat',
                    'meeting_status',
                    'published',
                    'agenda',
                    'address',
                    'lat_lng',
                    'created_for'
                    ]));
                $meeting->created_by = $user->id;
                $meeting->file = $filePath;
                $meeting->image = $imagePath;
                $meeting->from_date = $date->format("Y-m-d")." ".$begin->format("H:i:s");
                $meeting->to_date = $date->format("Y-m-d")." ".$end->format("H:i:s");
                $meeting->save();
                $meetingIds[] = $meeting->id;
            }
           // MeetingDetail::insert($meeting_details);
        } 
        else 
        {
            $meeting = new Meeting;
            $meeting->fill($request->only([
                'title',
                'repeat',
                'meeting_status',
                'published',
                'agenda',
                'address',
                'lat_lng',
                'created_for'
                ]));
            $meeting->created_by = $user->id;
            $meeting->file = $filePath;
            $meeting->image = $imagePath;
            $meeting->from_date = $begin->format("Y-m-d H:i:s");
            $meeting->to_date = $end->format("Y-m-d H:i:s");
            $meeting->save();
            $meetingIds[] = $meeting->id;
            
        }

        foreach ($meetingIds as $meeting_id) {
            $participants = [];
            $participants[]=[
                'meeting_id' => $meeting_id,
                'user_email' => $created_for->email,
                'is_owner' => 1,
                'accept_status' => 1, // 0 = not answered, 1 = yes, 2 = no, 3 = maybe
                'name' => $created_for->name
            ];
            if($reqParticipants){
                foreach ($reqParticipants as $p) {
                    $participants[]=[
                        'meeting_id' => $meeting_id,
                        'user_email' => $p->user_email,
                        'is_owner' => 0,
                        'accept_status' => 0,
                        'name' => $p->name
                    ];
                }
            }
            MeetingParticipant::insert($participants);
        }

        $returnMessage = array(
            'success' => true,
            'errors' => null,
            'message'       => 'saved'
            
        );
        return response()->json($returnMessage);
        
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        $meeting = Meeting::with(['participants:id,name,user_email,meeting_id'])->find($id);
        return $meeting;
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(Request $request, $id)
    {
        $user= auth('api')->user();
        $rules = array(
            'title'       => 'required|max:255',
            'from_date'       => 'required|date',
            'to_date'       => 'required|date|after:from_date',
            'type' => 'required|integer',
            'meeting_status' => 'required|integer',
            'published' => [
                'required',
                Rule::in([0, 1]),
            ],
            'created_for' => 'required|exists:users,id',
            'participants' => 'array',
            //'participants.*.id' => 'required_with:participants.*.user_email',
            'participants.*.user_email' => 'filled|email|distinct',
            'participants.*.name' => 'required_with:participants.*.user_email'
        );

        $messages=array(
            'title.required' => 'Please enter a Title.'
        );

        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
            
            );
            
            return response()->json($returnMessage, 200);
        }
        
        $meeting = Meeting::with(['participants:id,name,user_email,meeting_id,is_owner'])->find($id);
        if($meeting->created_for != $user->id){
            $returnMessage = array(
                'success' => false,
                'errors' => 'This is not Yours to edit'
            );
            return response()->json($returnMessage, 200);
        }
        $created_for = User::find($request->created_for);
        $reqParticipants = collect($request->participants)->keyBy('user_email');
        $participants = $meeting->participants->keyBy('user_email');
        if($request->created_for == $meeting->created_for){
            $reqParticipants->put($created_for->email, $participants[$created_for->email]);
        }
        else {
            $reqParticipants->put($created_for->email, [
                //'id' => 0,
                'user_email' => $created_for->email,
                'is_owner' => 1,
                'accept_status' => 1, // 0 = not answered, 1 = yes, 2 = no, 3 = maybe
                'name' => $created_for->name
            ]);
        }
        //$participants->pull($created_for->email);
        $removed = $participants->diffKeys($reqParticipants)->flatten()->keyBy('id')->keys();
        //return $reqParticipants;
        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $name =  'file_'.uniqid().'.'.$request->file->getClientOriginalExtension();
            $destinationPath = public_path('/meeting');
            $file->move($destinationPath, $name);
            $meeting->file = "meeting/".$name;
        }
        if ($request->hasFile('image')) {
            $image = $request->file('image');
            $name =  'img_'.uniqid().'.'.$image->getClientOriginalExtension();
            $destinationPath = public_path('/meeting');
            $image->move($destinationPath, $name);
            $meeting->image = "meeting/".$name;
        }
        
        
        $begin = new \DateTime($request->from_date);
        $end = new \DateTime($request->to_date);
        $meeting->fill($request->only([
            'title',
            'repeat',
            'meeting_status',
            'published',
            'agenda',
            'address',
            'lat_lng',
            'created_for'
            ]));
        $meeting->created_by = $user->id;
        $meeting->from_date = $begin->format("Y-m-d H:i:s");
        $meeting->to_date = $end->format("Y-m-d H:i:s");
        $meeting->save();
        foreach ($reqParticipants as $key => $value) {
            
            if(!array_key_exists('is_owner', $value)){
                $value['is_owner'] = 0;
            }
            MeetingParticipant::updateOrCreate(
                ['meeting_id' => $id, 'user_email' => $value['user_email']],
                ['name' => $value['name'], 'is_owner' => $value['is_owner']]
            );
        }
        MeetingParticipant::destroy($removed);
        $returnMessage = array(
            'success' => true,
            'errors' => null,
            'message'       => 'saved'
            
        );
        return response()->json($returnMessage);
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

    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function userSuggestion()
    {
      
       $user= auth('api')->user();
        $userList = User::all(['id', 'name', 'email as user_email']);
        return $userList;
    }
}
