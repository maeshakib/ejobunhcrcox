<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Leave extends Model
{
    protected $guarded = [];

    public function leave_applications()
    {
        return $this->hasMany('App\LeaveApplication', 'leave_id');
    }
}
