<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class JobApplied extends Model
{
    public $timestamps = false;
    protected $dates = ['created_at'];
    protected $table='job_applieds';
    protected $fillable = [
        'jobeeker_user_id', 'job_post_id'
    ];

    public function users()
    {
        return $this->belongsToMany('App\User');
    }
 

}
