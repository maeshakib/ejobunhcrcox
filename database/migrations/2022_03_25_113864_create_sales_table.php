<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateSalesTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('sales', function (Blueprint $table) {
            $table->increments('id');
            $table->unsignedInteger('client_id');

            $table->string('invoice_no')->nullable()->unique();
            $table->float('sales_amount', 20, 2);
            $table->dateTime('sales_date');          
            $table->unsignedInteger('user_id');
            $table->string('sales_note')->nullable();
            $table->tinyInteger('payment_status')->nullable()->comment('0=unpaid,1=paid,2=partial paid');
            $table->tinyInteger('edit_status')->default(0);        
            $table->timestamps();
            
            $table->foreign('user_id')->references('id')->on('users');
            $table->foreign('client_id')->references('id')->on('clients');

        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('sales');
    }
}
