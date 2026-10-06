using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using DBProject.DAL;
using System.Data;



namespace DBProject
{
    public partial class AppointmentNotificationSent : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }


        //-----------------------Function1--------------------------//
        protected void sendARequest (object sender, EventArgs e)
        {
            myDAL objmyDAl = new myDAL();

            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            string dID1 = Session["dID"] != null ? (string)Session["dID"] : "0";

            int dID = Convert.ToInt32(dID1);

            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            int pID = Session["idoriginal"] != null ? (int)Session["idoriginal"] : 0;

            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            string temp = Session["freeSlot"] != null ? (string)Session["freeSlot"] : "0";

            int freeSlot = Convert.ToInt32(temp);

            string mes = "";

            int status = objmyDAl.insertAppointment(dID, pID, freeSlot, ref mes);


            if (status == -1)
            {
                Message.Text = "There was some error in sending appointment request to the Doctor.";
            }

            else
            {
                Message.Text = mes;
            }
            
            return;
        }



    }
    
}
