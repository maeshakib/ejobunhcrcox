<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Role extends Model
{
    public $timestamps = true;
    /*protected $fillable = [
        'name', 'description', 'status', 'created_at','updated_at'
    ];*/
	protected $guarded = array('id','is_deletable');	
	
	public function users()
    {
        return $this->hasMany(User::class);
    }
    
  


	public function permissions()
    {
        return $this->belongsToMany(Permission::class,'role_permissions','role_id','permission_id');
    }
}
