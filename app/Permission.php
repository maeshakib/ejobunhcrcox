<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Permission extends Model
{
    public $timestamps = false;
	protected $guarded = array('id');	

    public function parent() 
    {
	    return $this->belongsTo(Permission::class, 'parent_id');
	}

	  //each category might have multiple children
    public function children() 
    {
	    return $this->hasMany(Permission::class, 'parent_id','id' );
	}
	
	
}
