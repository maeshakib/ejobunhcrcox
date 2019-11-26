<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Meeting extends Model
{
    protected $guarded = [];
    
    public function participants()
    {
        return $this->hasMany('App\MeetingParticipant', 'meeting_id');
    }
}
