<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Target extends Model
{
    protected $guarded = [];
    public function getFromDateAttribute($value)
    {
        $time = strtotime($value);
        return date('Y-m-d',$time);
    }
    public function users()
    {
        return $this->belongsTo('App\User');
    }
}
