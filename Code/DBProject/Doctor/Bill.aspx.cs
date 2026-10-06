using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using DBProject.DAL;
using System.Data;

namespace doctor
{
    public partial class bill : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

            myDAL objmyDAL = new myDAL();
            DataTable dt = new DataTable();
            int found;

            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            int did = Session["idoriginal"] != null ? (int)Session["idoriginal"] : 0;
            
            found = objmyDAL.generate_bill_DAL(did, ref dt);

            if (found != 1)
            { Response.Write("<script>alert('There was some error');</script>"); }
            else
            {
                Label1.Text = dt.Rows[0][0].ToString();
            }
        }


        public void bill_paid(object sender, EventArgs e)
        {
            myDAL objmyDAL = new myDAL();
            
            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            int did = Session["idoriginal"] != null ? (int)Session["idoriginal"] : 0;
            int appoint = Session["appointid"] != null ? (int)Session["appointid"] : 0;
            objmyDAL.paid_bill_DAL(did,appoint);

			Response.BufferOutput = false;
            Response.Redirect("patienthistory.aspx");
        }


        public void bill_Unpaid(object sender, EventArgs e)
        {
            myDAL objmyDAL = new myDAL();

            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            int did = Session["idoriginal"] != null ? (int)Session["idoriginal"] : 0;
            int appoint = Session["appointid"] != null ? (int)Session["appointid"] : 0;
            objmyDAL.Unpaid_bill_DAL(did, appoint);

            Response.BufferOutput = false;
            Response.Redirect("patienthistory.aspx");
        }
    }
}
