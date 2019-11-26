<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Collection extends Model
{
    protected $guarded = [];
    public function sales()
    {
        return $this->belongsTo('App\Sale','sales_id');
    }
}
