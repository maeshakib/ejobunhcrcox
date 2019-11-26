<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateLocationAreasTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('location_areas', function (Blueprint $table) {
            $table->increments('id');
            $table->string('name');
            $table->integer('parent_id')->default(0);
            $table->unsignedInteger('location_level_id');
            $table->string('lat_lng')->nullable();
            $table->longText('map_data')->nullable();
            $table->string('description')->nullable();
            $table->timestamps();

            $table->foreign('location_level_id')
                    ->references('id')->on('location_levels')
                    ->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('location_areas');
    }
}
