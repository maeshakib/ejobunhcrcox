<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class LeaveApplication extends Model
{
    public function leave_type()
    {
        return $this->belongsTo('App\Leave', 'leave_id');

    }
    public function applicant()
    {
        return $this->belongsTo('App\User', 'user_id');
    }

    public function approved_by()
    {
        return $this->belongsTo('App\User', 'approved_by');
    }

}
